---
layout: post
theme:
  name: twitter
title: 系统消息队列（squid启动小故障）
date: 2010-04-30
category: linux
tags:
  - squid
---

昨天公司一台服务器被机房动手动脚之后，上面的虚拟机变得极不正常。squid基本跑不了三四个小时就out of memory一次。虽然已经把cache_mem调低到free的1/4了。依然如此。
更过分的事情刚才发生了，在又一次挂掉后，squid重启动彻底失败起不来了。
赶紧查看cache.log，其中记载了失败的原因，如下：

    storeDiskdInit: msgget: (28) No space left on device
    FATAL: msgget failed

一眼看起来像是磁盘空间满了，df一看，没问题呀，use才1%呢！
然后注意到其具体失败处，是msgget函数。msgget是用来新建/获取信息队列的。也就是说，信息队列的某个方面满了。查看一下这方面的信息：

    [root@sitesquid1 ~]# ipcs -l
    ------ Shared Memory Limits --------
    max number of segments = 4096
    max seg size (kbytes) = 67108864
    max total shared memory (kbytes) = 17179869184
    min seg size (bytes) = 1
    ------ Semaphore Limits --------
    max number of arrays = 128
    max semaphores per array = 250
    max semaphores system wide = 32000
    max ops per semop call = 32
    semaphore max value = 32767
    ------ Messages: Limits --------
    max queues system wide = 16
    max size of message (bytes) = 65536
    default max size of queue (bytes) = 65536

看着有点晕，队列系统宽度的最大值，这个比较难理解（下面明明有最大大小了呀？）。只好求助百度，原来就是能打开的消息队列的最大个数，或者说消息队列标识符的最大值。
看这个值挺小的，再看网上也有DB2和apache修改这个值的说法，那就修改一下试试：

    sysctl -w kernel.msgmni=128

再启动squid，OK！！
再重新看看消息队列标识符到底打开了多少：

    [root@spshort5 ~]# ipcs|awk '/msqid/{a=NR}END{print NR-a}'
    19

果然是超过16。


