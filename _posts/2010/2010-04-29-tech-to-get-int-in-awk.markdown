---
layout: post
title: awk取数值小技巧
date: 2010-04-29
category: bash
tags:
  - awk
---

今天在Q群里看到有人在取ping值时用的小技巧，很是不错，加深了对awk的理解。
ping命令输出如下：

64 bytes from xd-22-5-a8.bta.net.cn (202.108.22.5): icmp_seq=1 ttl=55 time=20.7 ms

要取20.7出来，一般会指定=和" "两个FS，然后取NF-1列。

不过这个群友给出另一个办法，指定=为FS，然后取$NF+0，其值就是20.7了！

很好很好，采用一个+0的计算，等于是指定前面的$NF为数字型，于是~~

不过这个字母不能在数字前面，否则awk会认为是0。例如下：

    echo 123ms|awk '{print $1+0}'
    123
    echo ms123|awk '{print $1+0}'
    0

