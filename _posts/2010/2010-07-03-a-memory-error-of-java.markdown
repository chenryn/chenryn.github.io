---
layout: post
theme:
  name: twitter
title: Java报错一例
date: 2010-07-03
category: java
---

新迁移一例apache+resin系统，运行不久后时不时就出现500错误。从日志中看到如下报错：

    OutOfMemoryError: PermGen space

内存溢出，可是free、top来看，mem和swap都还有很多空闲~
于是去谷歌一下，看到如下说法：

PermGen space全称Permanent Generation space（永久保存内存区），这部分内存用来保存Class和Meta的信息——Class在load的时候进入PermGen，之后Java运行时，GC（垃圾回收机制）就不再去管这部分内容了。当resin对jsp进行percompile时，可能就导致内存溢出了……默认空间为4M！
Heap space（JVM运行调用的内存区），JVM启动时，默认的初始空间Xms是物理内存的1/64，最大空间Xmx是物理内存的1/4。建议指定Xms和Xmx相同（小于物理内存的80%），然后Xmn为Xmx的1/4。

解决办法：

修改java启动参数，追加“-Xms256m -Xmx256m -XX:MaxNewSize=256m -XX:MaxPermSize=256m”，定死space大小。
重启至今故障未出现。


