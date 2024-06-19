---
layout: post
theme:
  name: twitter
title: BSD上的流量监控脚本
date: 2011-03-21
category: monitor
tags:
  - FreeBSD
  - awk
---

之前有过一篇linux上的流量监控脚本的博文，是利用procfs进行数据运算。但BSD上的procfs和linux有所不同，它只包含了进程的信息，没有系统的统计。所以只能通过其他方法。
linux上另一种获取网卡总流量的方法是ifconfig命令，这个命令其实也是读取proc；但是BSD上的ifconfig输出里也没有……
不过BSD上倒不是没法查流量上，事实上另外有两个命令，在实时观测中更加好用，一个是systat -if 1，几乎就是一个无色版的iptraf；另一个是netstat -idbhI bce0 1。
解释一下，systat是bsd上用来查看系统信息的一个超级利器，-if是-ifstat的简写，类似还有-vmstat等等。netstat是专门用来显示网络状态的，最常用的就是-ant显示所有的TCP链接，这里用的idbhI，表示interface、drop、bytes、human，也就是用方便读取的格式输出某网卡的流量值。
但是这两个命令，都是持续输出，必须接到^C信号才会退出运行。在实时管理时很好用，在做监控脚本的时候，就弄巧成拙了……
好在netstat参数多，调整一下，使用idbnf参数（family）即可输出网卡总流量值，然后按照linux上一样的思路进行计算了。
最终脚本如下：
```bash#!/bin/bash
/usr/local/bin/gawk 'BEGIN{flow="netstat -idbnf inet";while((flow) | getline){now_in[$1]=$7;now_out[$1]=$10};time=systime()}{if_in[$1]=(now_in[$1]-$2)*8/(time-$4);if_out[$1]=(now_out[$1]-$3)*8/(time-$4)}END{printf "OK. The flow is %.2f,%.2f,%.2f,%.2f Kbps | bce0_in=%d;0;0;0;0 bce0_out=%d;0;0;0;0 bce1_in=%d;0;0;0;0 bce1_out=%d;0;0;0;0",if_in["bce0"]/1024,if_out["bce0"]/1024,if_in["bce1"]/1024,if_out["bce1"]/1024,if_in["bce0"],if_out["bce0"],if_in["bce1"],if_out["bce1"];for(i in now_in){print i,now_in[i],now_out[i],time > "/tmp/if_flow.txt"}}' /tmp/if_flow.txt
```
脚本就一行，不过就有一个缺点比不上分开写很多行的shell脚本，第一次运行前必须手动touch /tmp/if_flow.txt。因为如果这个文件不存在的话，awk会报错，执行不到END{}来，不会自动生成这个文件的……
另：systime()函数是gawk特有的，而BSD上默认的是awk，所以需要安装gawk（在/usr/ports/lang/gawk目录下make&amp;&amp;make install）；或者在awk中采用shell变量，定义time='`date +%s`'来调用了。
