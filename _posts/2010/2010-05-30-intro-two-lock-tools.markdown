---
layout: post
title: 文件锁和 CPU 绑定
date: 2010-05-30
category: linux
tags:
  - taskset
  - flock
---

从网上看到的两个锁定，都是util-linux包里的。

一个是flock。我从字面上猜测是文件描述符锁~~help显示如下：

    flock (util-linux 2.13-pre7)    
    Usage: flock [-sxun][-w #] fd#
           flock [-sxon][-w #] file [-c] command...
      -s  --shared     Get a shared lock
      -x  --exclusive  Get an exclusive lock
      -u  --unlock     Remove a lock
      -n  --nonblock   Fail rather than wait
      -w  --timeout    Wait for a limited amount of time
      -o  --close      Close file descriptor before running command
      -c  --command    Run a single command string through the shell
      -h  --help       Display this text
      -V  --version    Display version

比如在rsync定时同步某文件夹的时候，可能担心上一次任务还没执行完，下一次就开始了。于是可以采用如下方式：

    1 * * * * flock -xn /var/run/rsync.lock -c 'rsync -avlR /data/files 172.16.xxx.xxx:/data'

对照usage，x创建一个独享锁，n是如果已存在就退出（这点扶凯说是就等待，但我觉得从help来看是退出，然后等下一分钟重新探测），然后一个lock文件，c是shell命令，具体内容就是rsync。
另一个是taskset，同样字面来看，任务设定锁。help如下：

    taskset (util-linux 2.13-pre7)    
    usage: taskset [options] [mask | cpu-list] [pid | cmd [args...]]
    set or get the affinity of a process
      -p, --pid                  operate on existing given pid    
      -c, --cpu-list             display and specify cpus in list format
      -h, --help                 display this help
      -v, --version              output version information</p>
    The default behavior is to run a new command:    
      taskset 03 sshd -b 1024
    You can retrieve the mask of an existing task:
      taskset -p 700
    Or set it:
      taskset -p 03 700
    List format uses a comma-separated list instead of a mask:
      taskset -pc 0,3,7-11 700
    Ranges in list format can take a stride argument:
      e.g. 0-31:2 is equivalent to mask 0x55555555

用这个命令，可以把不同的进程，锁定在不同的CPU上完成。这个做法，之前在nginx优化上曾经碰到过，不过那是nginx自带的功能。<br />在CU上看到有人提起squid与CPU，squid是只支持单CPU的，不过可以通过在不同端口开启多squid进程的办法来完成对多CPU的利用，一般情况下，各squid进程会自动分配在不同CPU上跑，不过这个是系统的资源分配，难保出问题，就可以用这个命令完成锁定了。
