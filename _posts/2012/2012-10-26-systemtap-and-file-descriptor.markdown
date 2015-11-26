---
layout: post
title: 用systemtap调试文件描述符限制
category: linux
tags:
  - systemtap
  - C
---
在运行一些非root用户进程的时候，我们都习惯要在前面加上一个ulimit -HSn 65535的命令。而且我们还知道关于文件描述符的限制，不止这一个地方，还有limits.conf，sysctl -w fs.file-max等等。但是到底这些是什么个关系呢？而且，如果是一个已经在运行的程序，有没有可能在更改他的文件描述符限制呢？

以最经常碰到这种情况的squid为例。我们可以在squid/src/comm.c里看到`comm_openex()`是如何发现超出限制的，嗯，可以说没有"自己发现"，直接判断socket()是否成功而已。所以接下来的事情是看socket创建过程怎么判断的。

关于socket过程，主要看kernel/net/socket.c和kernel/fs/file.c，作为C菜鸟，如下系列博文在这方面说的非常清楚，我就不详细说了：

[TCP/IP源码学习(47)——socket与VFS的关联(1)](http://blog.chinaunix.net/uid-23629988-id-3080166.html)

[TCP/IP源码学习(48)——socket与VFS的关联(2)](http://blog.chinaunix.net/uid-23629988-id-3083376.html)

大体来说，就是socket本身是不触及这个限制的，但是创建出来的socket必须和文件描述符关联起来(`sock_map_fd()` -- `sock_alloc_file()` -- `get_unused_fd_flags()` -- `alloc_fd()`)，这就相关了。在`alloc_fd()`中会读取当前进程(current)的fdtable，fdtable的结构由"linux/fdtable.h"定义如下：

```c
    struct fdtable {
        unsigned int max_fds;
        struct file ** fd;      /* current fd array */
        fd_set *close_on_exec;
        fd_set *open_fds;
        struct rcu_head rcu;
        struct fdtable *next;
    };
    struct files_struct {
        atomic_t count;
        struct fdtable *fdt;
        struct fdtable fdtab;
        spinlock_t file_lock ____cacheline_aligned_in_smp;
        int next_fd;
        struct embedded_fd_set close_on_exec_init;
        struct embedded_fd_set open_fds_init;
        struct file * fd_array[NR_OPEN_DEFAULT];
    };
    #define files_fdtable(files) (rcu_dereference((files)->fdt))
```

打开fd的过程如下：

1. 如果有files->next_fd，直接使用;
2. 否则从fdtable->open_fds->fds_bits[]找到fdtable->max_fds，到找到一个可用的为止;
3. 否则说明当前fdtable不够用，需要扩充expand_files();
4. 完成后把获得的fd+1赋值给files->next_fd，这样下次就可以直接用;
5. 最后把这个fd加入fdtable->open_fds里。

那么涉及max open files的显然就是这个`expand_files()`了。继续看，可以发现其中的判断分三部分：

1. if (nr >= current->signal->rlim[RLIMIT_NOFILE].rlim_cur)
2. if (nr < fdt->max_fds)
3. if (nr >= sysctl_nr_open)

都逃过之后才进入`expand_fdtable()`真正扩展。很好，现在我们看到之前就知道的ulimit/sysctl神马的是怎么限定的了。那么这第二个呢？我们可以找到files这个结构的init，如下：

```c
    struct files_struct init_files = {
        .count          = ATOMIC_INIT(1),
        .fdt            = &init_files.fdtab,
        .fdtab          = {
            .max_fds        = NR_OPEN_DEFAULT,
            .fd             = &init_files.fd_array[0],
            .close_on_exec  = (fd_set *)&init_files.close_on_exec_init,
            .open_fds       = (fd_set *)&init_files.open_fds_init,
            .rcu            = RCU_HEAD_INIT,
        },
        .file_lock      = __SPIN_LOCK_UNLOCKED(init_task.file_lock),
    };
```

这个`NR_OPEN_DEFAULT`可以在fdtable.h里看到就是`BITS_PER_LONG`。`BITS_PER_LONG`应该是32或者64，取决于CPU是32还是64位的了。

其实这里还可以继续看`alloc_fdtable()`中怎么确定新扩展的`fdt->max_fds`的，如果nr大于sysctl的设定，那么nr会计算成

```c
    ((sysctl_nr_open - 1) | (BITS_PER_LONG - 1)) + 1
```

然后`copy_fdtable()`转移数据，奇怪的是看到转移完后，还判断了原有`fdt->max_fds > NR_OPEN_DEFAULT`才释放，我不清楚什么情况下会有`fdt->max_fds`小于init值了...

回到主题。三个条件里后两个条件都很明白了。现在就是第一个，这是根据current不同有不同的，我们可以试试看如果修改这个值会怎么样？

修改工具我用到了systemtap大神器，不过我是菜鸟啦～脚本如下：

```c
    #!/usr/bin/stap
    %{
    #include <linux/sched.h>
    #include <linux/resource.h>
    %}
    probe begin {
        printf("begin...\n")
    }
    probe kernel.function("expand_files@fs/file.c").call
    {
        if ( execname() == "squid" ) {
            printf("[%s] %s fdt:%d, task:%d, rlim:%d\n", tz_ctime(gettimeofday_s()), execname(), $files->fdtab->max_fds, task_open_file_handles(task_current()), rlim_cur());
            printf("\targs_nr: %d\n", $nr);
            if ( rlim_cur() < $1 ) {
                printf("\tset rlim: %d\n", set_rlim_cur($1));
                exit();
            }
        }
    }
    probe kernel.function("expand_files@fs/file.c").return
    {
        if ( execname() == "squid" ) {
            printf("\treturn: %d\n", $return);
        }
    }
    probe kernel.function("expand_fdtable")
    {
        printf("%s call fdtable with %s", execname(), $$vars);
    }
    function rlim_cur:long ()
    %{ /* pure */ /* unprivileged */
        struct signal_struct *ss = kread( &(current->signal) );
        THIS->__retvalue = kread (&(ss->rlim[RLIMIT_NOFILE].rlim_cur));
        CATCH_DEREF_FAULT();
    %}
    function set_rlim_cur:long (val:long)
    %{ /* pure */ /* unprivileged */
        struct signal_struct *ss = kread( &(current->signal) );
        kwrite(&(ss->rlim[RLIMIT_NOFILE].rlim_cur), THIS->val);
        CATCH_DEREF_FAULT();
    %}
```

systemtap自己提供了一系列tapset函数，比如这里的execname(),task\_\*都是。注意systemtap是脚本语言的，所以这些函数直接在/usr/share/systemtap/下面可以看怎么写的。比如我上面定义的两个function就是仿照里面`task_max_file_handles()`写的。

用%和{}标记的是内嵌C代码，systemtap在编译成C的时候直接插入进去，可以stap -k保留在/tmp/stap123456下查看的到。

kread/kwrite是systemtap-runtime提供的函数，封装的是put\_user/get\_user指令。

现在我们启动squid进程和stap脚本：

```bash
    ulimit -HSn 256;squid -D
    stap -g max_fds.stp 1024
```

注意要加-g，否则不会加载内嵌C的。
另开窗口发起一次请求，然后看到stap输出：

    begin...
    [Fri Oct 26 19:20:34 2012 CST] squid fdt:64, task:16, rlim:256
            args_nr: 12
            set rlim: 0

额，这个set是返回值0。function里如果把kwrite的返回值赋给`THIS->retvalue`会报void的错误。挺奇怪的。

再运行stap，发起请求，就可以看到squid的rlim变成1024了：

    begin...
    [Fri Oct 26 19:24:40 2012 CST] squid fdt:64, task:16, rlim:1024
            args_nr: 12
            return: 0
    [Fri Oct 26 19:24:40 2012 CST] squid fdt:64, task:17, rlim:1024
            args_nr: 17
            return: 0

不过我的虚拟机跑不出这么大的并发，没法超过`BITS_PER_LONG`的64。所以我们可以换一个思路来验证`expand_files()`的执行。

* 先ulimit -HSn 16启动squid，然后stap修改到1024

这个时候，搞笑而现实的事情发生了。nr越过了1024的判断，却越不过`BITS_PER_LONG`的判断，于是`expand_files`永远过不去。squid的max open files只能停留在16。这一步的return是0。所以看到stap里.return{}打印的是0。

* 先ulimit -HSn 1024启动squid，然后stap修改到16

这个时候，由之前的测试可以看到，squid本身就要用掉十多个fd来维护运行的。所以基本一接请求nr就超过16了。squid完全无法响应请求。这一步的return是-EMFILE，于是屏幕上开始出现一行行squid call fdtable {.n}.........

附注：使用systemtap需要debuginfo。内核调试需要kernel-debuginfo/kernel-devel，程序也需要。如果是自己编译的，没问题直接probe process("${path}/command")即可，如果是rpm安装的，那就必须得把debuginfo包安装上，比如nginx-debuginfo.rpm这样子。

2012年12月3日更新：

采用tc延时的办法，可以达到在虚拟机上获取squid高连接的模拟环境。然后作出如下修正：

* 在修改`rlim_cur`的时候也需要修改`rlim_max`

在上面的缩小测试里不会触发问题，不过在增大的测试中，问题来了——`setrlimit()`函数会很诧异为毛自己参数里那个`&rl`的`rlim_cur`比`rlim_max`还大？然后悲剧的报出"etrlimit(RLIMIT\_NOFILE) failed: Invalid argument (22)"的错误……

```c
    kwrite(&(ss->rlim[RLIMIT_NOFILE].rlim_max), THIS->val);
```

* 对于squid还需要修改`Squid_MaxFD`全局变量

上面都是对kernel里的socket和file的修改，在实际运用中，用户程序本身也会有各种判断。squid维护了一堆全局变量，比如`Squid_MaxFD`，`Biggest_FD`和`Number_FD`，这就是squidclient mgr:info里看到的关于文件描述符的那几个值。其中`Squid_MaxFD`是在init的时候根据主进程启动时的ulimit情况一次性设定的，即便child进程重启也不会变。而`Biggest_FD`则是由`fdUpdateBiggest()`函数每次更新。不巧的是，里面有这么一句判断：

```c
    assert(fd < Squid_MaxFD);
```

所以，光修改kernel里的限制，socket返回后在更新`Biggest_FD`时squid会直接挂掉……

下面是修改squid进程里全局变量的办法，和修改kernel其实很类似：

```c
probe process("/usr/sbin/squid").function("fdUpdateBiggest@src/fd.c")        
{                                                                            
    if ( $Squid_MaxFD < 65535 ) {                                            
        $Squid_MaxFD = 65535;                                                
    }                                                                        
} 
```

把上面两个修改加入到之前的文件，然后测试增大ulimit限制(记住ulimit要大于64，否则不起作用哟)，就没问题了。

