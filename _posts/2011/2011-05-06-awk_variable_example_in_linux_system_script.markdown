---
layout: post
theme:
  name: twitter
title: linux系统脚本中的awk一例
date: 2011-05-06
category: bash
tags:
  - awk
---

感谢@snowave童鞋，摘取了/usr/bin/run-parts最后一段的awk内容给我看：

$i 2>&amp;1 | awk -v "progname=$i" 'progname {print progname ":\n";progname="";} { print; }'

上面这行其实相当于$i 2>&amp;1 | awk 'BEGIN{print "'$i':\n"}{print}' ，解释一下原版的用法：

-v是定义一个awk内的变量，用来传递外面的shell变量到awk里；
progname是就是如果存在这个变量执行下面语句段；
然后在第一次print了之后把progname变量清空了，之后就不会再执行了。
最后的print就是显示管道出来的结果了。

不过在我的理解和实验中，每次都经过一次if判断，执行效率远远不如begin处理。不知道为什么系统脚本会采用这种写法~~
