---
layout: post
title: awk单行实践
date: 2009-11-19
category: bash
tags:
  - awk
---

客户提交一份预加载文件列表，采用了如下格式：
http://www.a.com/a/b/
a b c d e f g
h i j k l m n
http://www.b.com/b/c/
o p q r s t
u v w x y z
http://www.c.com/d/e
http://www.d.com/f/g
必须要把文件整理成完整的url，才好操作。
最初的设想，是以带http开头的行为RS，以n为OFS，然后打印RS
$0。随后发现这个想法问题多多——最主要的一点是：直接print $0的话，输出结果是不显示OFS的。
然后我才想到用for循环打印所有列的话，默认就已经分行了，不用定义OFS和ORS。
剩下的问题就是RS，然而不管我怎么写正则匹配表达式，结果都搞不定……唉
最后只能放弃这个想法，采用比较繁琐的办法：

awk -v RS="http" '{if($2==""){print RS$1>url}else{for(i=2;i<=NF;i++){print RS$1$i>url}}}' URLFILE

需要注意的一点，这里RS$1$i之间有没有空格（但不能是逗号）都不影响结果，但如果是{x=$1}{print RS x$i}的话，RS和x之间就必须有空格！
这样5000个错乱的url，一敲回车就输出成一个url文件，列好了完整的url列表。然后for;do wget;done搞定预加载~~

