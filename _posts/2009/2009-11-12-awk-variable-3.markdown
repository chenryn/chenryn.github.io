---
layout: post
theme:
  name: twitter
title: awk变量（三续）
date: 2009-11-12
category: bash
tags:
  - awk
---

网上闲逛，偶然看到一句统计TCP连接数的命令如右：netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'

要统计TCP连接数，其实用上wc命令，倒不甚难。不过为了熟悉NF的用途，便细细试试这条吧。
先看试验中netstat -n的结果：
```bash
[root@raocl rao]# netstat -n |awk '/^tcp/{print $0}'
tcp 0 0 211.151.70.76:80 60.12.137.170:3157 SYN_RECV
tcp 0 0 211.151.70.76:80 117.136.0.184:53476 SYN_RECV
tcp 0 0 211.151.70.76:80 112.193.8.170:4281 SYN_RECV
tcp 0 0 211.151.70.76:80 112.65.48.252:62480 ESTABLISHED
tcp 0 0 211.151.70.76:80 113.205.102.168:3230 ESTABLISHED
tcp 0 0 211.151.70.76:80 198.54.202.250:2714 ESTABLISHED
tcp 0 1370 211.151.70.76:80 222.44.43.141:2070 FIN_WAIT1
tcp 0 0 211.151.70.76:80 220.248.86.74:53112 ESTABLISHED
……（下略）
```
然后详细打印一下那条命令里NF的每一个变化使用值：
```bash
[root@raocl rao]# netstat -n | awk '/^tcp/ {print ++S[$NF],S[$NF],$NF,NF}'
……（上略）
532 532 ESTABLISHED 6
8 8 LAST_ACK 6
533 533 ESTABLISHED 6
534 534 ESTABLISHED 6
33 33 TIME_WAIT 6
535 535 ESTABLISHED 6
536 536 ESTABLISHED 6
```
也就是利用awk的行处理特性，遍历了所有tcp开头的行。定义出不同状态命名的数组下标，并分别++计数赋值给数组元素。
最后，打印数组S，如下：
```bash
[root@tinysquid2 ~]# netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'
TIME_WAIT 18
FIN_WAIT1 33
FIN_WAIT2 1
ESTABLISHED 508
SYN_RECV 5
LAST_ACK 11
```

