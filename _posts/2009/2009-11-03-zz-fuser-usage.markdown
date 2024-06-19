---
layout: post
theme:
  name: twitter
title: fuser命令（转）
date: 2009-11-03
category: bash
---

fuser：使用文件或者套节字来表示识别进程。我常用的他的两个功能：查看我需要的进程和我要杀死我查到的进程。

比如当你想umount光驱的时候，结果系统提示你设备正在使用或者正忙，可是你又找不到到底谁使用了他。这个时候fuser可派上用场了。
```bash
[root@lancy sbin]# umount /media/cdrom
umount: /media/cdrom: device is busy
umount: /media/cdrom: device is busy
eject: unmount of `/media/cdrom' failed
[root@lancy sbin]# fuser /mnt/cdrom
/mnt/cdrom: 4561c 5382c
[root@lancy sbin]# ps -ef |egrep '(4561|5382)' |grep -v grep
root 4561 4227 0 20:13 pts/1 00:00:00 bash
root 5382 4561 0 21:42 pts/1 00:00:00 vim Autorun.inf
```
示例中，我想弹出光驱，系统告诉我设备忙着，于是采用fuser命令，参数是你文件或scoket，fuser将查出那些使用了他。

4561c,5382c表示目前用两个进程在占用着/mnt/cdrom，分别是4561,5382,进程ID后的字母表示占用资源的方式，有下面几种表示：

    c 当前路径(current directory.)我的理解是表示这个资源的占用是以文件目录方式，也就是进进入了需要释放的资源的路径，这是最常用的资源占用方式。
    e 正在运行可执行文件（executable being run.），比如运行了光盘上的某个程序
    f 打开文件（ open file），缺省模式下f忽略。所以上面的例子中，虽然是开打了光盘上的Autorun.inf文件，但是给出的标识是c，而不是f。
    r root目录（root directory）.没有明白什么意思，难道是说进入了/root这个特定目录？
    m mmap文件或者共享库( mmap’ed file or shared library).这应该是说某个进程使用了你要释放的资源的某个共享文件。

在查找的同时，你还可定指定一些参数，比如

    -k 杀死这些正在访问这些文件的进程。除非使用-signal修改信号，否则将发送SIGKILL信号。
    -i 交互模式
    -l 列出所有已知的信号名称。
    -n 空间，选择不同的名字空间，可是file,udp,tcp。默认是file，也就是文件。
    -signal 指定发送的信号，而不是缺省的SIGKILL
    -4 仅查询IPV4套接字
    -6 仅查询IPV6套接字
    - 重置所有的选项，将信息设回SIGKILL

再看下面的例子
```bash
[root@lancy sbin]# fuser -l
HUP INT QUIT ILL TRAP ABRT IOT BUS FPE KILL USR1 SEGV USR2 PIPE
ALRM TERM
STKFLT CHLD CONT STOP TSTP TTIN TTOU URG XCPU XFSZ VTALRM PROF
WINCH IO PWR SYS
UNUSED
```
现在我们试试fuser -k的威力：
```bash
[root@lancy sbin]# fuser -k /mnt/cdrom
/mnt/cdrom: 4561c 5382c
kill 5382: 没有那个进程
No automatic removal. Please use umount /media/cdrom
[root@lancy sbin]# eject
```
套节字方式的使用：
```bash
[root@lancy sbin]# fuser -4 -n tcp 3306
here: 3306
3306/tcp: 5595
[root@lancy sbin]# ps -ef |grep 5595 |grep -v grep
mysql 5595 5563 0 22:24 pts/0 00:00:00 /usr/libexec/mysqld
--defaults-file=/etc/my.cnf --basedir=/usr --datadir=/var/lib/mysql
--user=mysql --pid-file=/var/run/mysqld/mysqld.pid --skip-locking
--socket=/var/lib/mysql/mysql.sock
[root@lancy sbin]# fuser -4 -n tcp 80
here: 80
80/tcp: 5685 5688 5689 5690 5691 5692 5693 5694 5695
```


