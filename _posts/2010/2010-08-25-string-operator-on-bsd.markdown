---
layout: post
title: BSD下的字符串运算
date: 2010-08-25
category: bash
tags:
  - FreeBSD
---

之前在linux上有个脚本，通过expr命令截取字符串的。大意如下：
    a=/path/to/example
    b=`expr length "$a  "`
    c=/path/to/example/file/to/example
    d=`expr length "$c"`
    e=`expr substr "$c" "$b" "$d"`
转移到BSD后，脚本报错：expr: syntax error
分别在linux和bsd上man expr后对比了一下，发现bsd上的expr确实没有index、length、substr等运算，原来linux上的expr是GNU的；而bsd上的expr是POSIX的，没有gnu的那些扩展用法……
于是必须使用些通用的办法来完成这个截取功能。方法很多，举例如下：

1、awk法
awk 'BEGIN{print length('$a')}';
awk 'BEGIN{print substr('$c','$b','$d')}'

2、bash扩展法
${#a}
${c:$b:${#c}}

3、标准expr+cut法
expr "$a  " : ".*"
echo $c | cut -c $b-$d

POSIX下的expr没有length，不过man中提供了采用:匹配.*的方法获取长度；

GNU下的expr substr和awk的substr函数一样，都是从$b位开始，截取$d位数的字符子串；而cut命令则是从$b位开始截取到$d位为止的字符子串。

其实cut这种方法才是最符合前面的length的，不过substr的时候，位数多设一些，也不影响结果~~
