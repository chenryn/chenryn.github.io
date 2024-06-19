---
layout: post
theme:
  name: twitter
title: date的一个怪问题
date: 2010-04-03
category: bash
---

今天看同事的一个备份脚本，在取昨天的日期时，采用了YESTERDAY_NAME=`date -I -d'-1 day' +"%Y-%m-%d"`的方法。

我对这个方法比较感兴趣，赶紧试试，结果赫然返回“date: multiple output formats specified”的报错来！

而单独采用date -I -d'-1 day'或者date -d'-1 day' +"%Y-%m-%d"这两种方法，都能返回正确结果。

返回同事的机器上，运行原命令确实没有问题。于是开始查版本，我的机器bash是3.2.25，date是5.97；他的bash是3.0.0.9，date是5.2.1。

不过在date -help中，不论是我的，还是他的机器上，都没发现-I这个option！！

为了移植性，同事也更改脚本删除了-I。不过之前脚本中为什么有这个，为什么还就真能跑，真是怪事~~
