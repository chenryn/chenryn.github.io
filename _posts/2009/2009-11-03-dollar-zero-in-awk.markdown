---
layout: post
title: awk变量$0妙用
date: 2009-11-03
category: bash
tags:
  - awk
---

接着说上篇的脚本。
因为看awk看的入迷，边想把exp.log的处理那段都用awk写出来。惊喜的发现awk有个内置参数NR，而且awk内部也可以进行运算。
于是上次的脚本就改成了这个样子：
```bash
#!/bin/bash
for ip in `cat ip.lst`
do
./ssh.exp $ip > /dev/null 2&>1
done
NK=`awk 'BEGIN{bs=4000000}/access/{if($1>bs){nk=NR-1;print nk}}' exp.log`
for nnk in $NK
do
awk -F"[@|']" 'NR=='"$nnk"' {print $2}' exp.log
done
```
然后又发现awk中$0的鬼怪。于是进一步简化成了这个样子：
```bash
#!/bin/bash
for ip in
`cat ip.lst`
do
./ssh.exp $ip > /dev/null 2&>1
done
awk 'BEGIN{bs=4000000}/access/{if($1>bs)print x};{x=$0}' exp.log|awk -F"[@|']" '{print $2}'
```
终于算是圆了自己用一句话搞定它的梦。yeah～
不过对这个原理还是不很明白。因为print x;x=$0出来是上一行，但print $0则是本行。why?
网上对打印前一行还提出另一个写法，就看的更莫名其妙了：
```bash
awk '/regex/{print (x==""?"":x)};{x=$0}' $1
```
而打印后一行是这样：
```bash
awk '/regex/{getline;print}' $1
```
不过这毕竟是恰好上下行而已，如果是要前几行的，还是要靠NR运算了。
<hr />
这个问题现在已经知道了，因为awk的流式处理，print x;x=$0，这个时候的x要等到下一行时才print出来。
