---
layout: post
theme:
  name: twitter
title: 限制单个进程的带宽
category: linux
tags:
  - iptables
  - cgroups
  - tc
---

限制带宽简直就是系统管理员的永恒话题之一。当然我这里就不讨论端口限速什么的了，百度一下一大把。但如果要的是限制某个特定进程的带宽，事情就有趣多了。

# iptables

大多数文档还是提供的传统思路，用 `iptables` 的 `owner` 模块，给 `--pid-owner` 加上 `MARK`，然后 `tc` 里针对这个 MARK 做限速。用法和限制如 <http://lists.netisland.net/archives/plug/plug-2004-09/msg00454.html> 说的这样。不过和这个快十年前的文章相比，现在的服务器上，基本已经普及了 SMP ，更进一步的，内核已经在自动发现支持 SMP 的时候，在 iptables 里把 owner 模块的 pid/cmd/sid 三个 match 都去掉了！现在的 owner 里只有 uid/gid 两个。所以这条路，在生产环境上基本行不通。

在 [stackexchange](http://unix.stackexchange.com/questions/34116/how-can-i-limit-the-bandwidth-used-by-a-process) 上，大家集思广益、献策献宝，又提出了另外两个工具，那个叫 `pipeviewer` 的应用场景比较特定(楼主问题是发生在 sshfs 上)，就不多说了。剩下这个 `trickle` 真是小众利器。值得一提：

# trickle

官方主页：<http://monkey.org/~marius/pages/?page=trickle>

这是一个在 BSD 上诞生的项目，官网上说只在 i386 的 linux 验证过。不过我在 x86\_64 的 linux 替大家尝试了一把，没有问题~

```bash
    yum install libevent-devel
    wget http://monkey.org/~marius/trickle/trickle-1.06.tar.gz
    tar zvxf trickle-1.06.tar.gz
    cd trickle-1.06
    ./configure
    # 生成的 config.h 里重复定义了 in_addr_t 结构体
    # 跟 include 的 /usr/include/netinet/in.h 里冲突
    # 会报错 "error: two or more data types in declaration specifiers"
    sed -i 's!\(#define in_addr_t\)!//\1!' config.h
    make
    make install
```

命令使用非常简单：

```bash
    trickle -s -d 100 wget http://domain/path/to/file.suffix -O /dev/null
```

* -s 表示独立运行，因为 trickle 还有一个 trickled 管理端可以用；
* -d 表示下载方向；
* -u 表示上传方向，两个的单位都是KB/s。

这个工具使用了 ELF 的 preloader 机制，在命令执行的时候替换掉标准库中的 socket recv() 和 send() 部分，达到限速的效果。其原理图在[官方PDF](http://monkey.org/~marius/trickle/trickle.pdf) 中，如下：

![](/images/uploads/trickle.png)

__不过总监大人及时提示我们： 由于该机制的限制，此工具对静态编译的程序无效，对采用 suid 的程序无效！__

# cgroup

排除上面两个无效，其实 trickle 依然无法覆盖全部应用场景 —— 比如说已经启动的后台进程长期运行，我有 pid ，但是不想中断掉重新起来；或者说这个进程可能我想让他白天跑 10MBps 晚上跑 40MBps 这样动态的。

这个时候就需要动用一些高级工具了，欢迎 `CGROUP` 上场。

`cgroup` 有 `net_cls` 控制器。不过和其他控制器不太一样的是它不直接控制网络读写，只是给网络包打上一个标记，然后把专业的事情交给专业的 TC 去做。嗯，思路和原先的 iptable 是很类似的。

参考文档很少，感觉大家使用 cgroup 都集中在 cpu 和 blkio 方面了。目前所见只有 [redhat](https://access.redhat.com/knowledge/articles/215353) 这个 pdf：<http://vger.kernel.org/netconf2009_slides/Network%20Control%20Group%20Whitepaper.odt> 。实施步骤如下：

## 启用 tc 

```bash
    tc qdisc del dev eth0 root
    tc qdisc add dev eth0 root handle 1: htb
    tc class add dev eth0 parent 1: classid 1: htb rate 1000mbit ceil 1000mbit
    tc class add dev eth0 parent 1: classid 1:3 htb rate 10mbit 
    tc class add dev eth0 parent 1: classid 1:4 htb rate 10kbit
    tc filter add dev eth0 protocol ip parent 1:0 prio 1 handle 1: cgroup
```

## 配置 cgroup

```bash
    # 命令行使用
    mount -t cgroup net_cls -o net_cls /cgroup/net_cls/
    cd !$
    cgcreate -g net_cls:test
    echo '0x10004' > /cgroup/net_cls/test/net_cls.classid 
    # 然后可以导出成文件之后通过工具管理
    yum install -y libcgroup
    cgsnapshot -s > /etc/cgconfig.conf
    /etc/init.d/cgconfig restart
```

## 测试 cgroup 效果

```bash
    time scp bigfile root@192.168.0.26:/tmp/
    time cgexec -g net_cls:test scp bigfile root@192.168.0.26:/tmp/
    echo $$ > /cgroup/net_cls/test/tasks
    tc class change dev eth0 parent 1: classid 1:4 htb rate 1mbit
    time scp bigfile root@192.168.0.26:/tmp/
```

可以看到后两次的速度比第一次慢很多。

第三次也被限制住，是因为 cgroup 会自动把子进程的 pid 也加入 tasks 里。

# 总结及其它

* trickle 在 download 的时候限制非常管用，在 upload 的时候大概起始速度会比限制值高几倍，然后以 100KB/s 的速度往下减。感觉是 smooth 的问题，不过调整相关参数也没见到区别。
* cgroup 给 tc 打标签的办法，看到 tc 限制下的速度波动比较大，猜测 tc 应该是类似 10 秒钟统计一次平均值是否超过限制这样的行为？
