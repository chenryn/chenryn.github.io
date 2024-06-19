---
layout: post
theme:
  name: twitter
title: $RANDOM变量妙用
date: 2010-06-23
category: bash
---

$RANDOM是linux自带的一个随机数变量，其随机范围从0-32767（man bash说的）。每次unset再恢复后，$RANDOM都会变化。

那么，在想获得某个范围内的随机数的时候，只需要很简单的利用一下这个变量就可以了。比如想随机生成一个C段的ip。如下：

echo 192.168.0.$[$RANDOM*255/32767]
192.168.0.71


