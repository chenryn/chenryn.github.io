---
layout: post
title: for/while循环的区别
date: 2010-12-16
category: bash
---

一般习惯使用for循环，在一年前写cgi的时候，还为这郁闷过一阵：for i in `cat ip`时，会自动的把文件中每行内容按照空格分割传递，最后采用先把空格改成+号的方式解决。

今天看CU，发现也有人提出这个问题，而解决办法很简单——用while循环即可。

另，while循环有两个用法，cat a|while read和while;do;done<a，pipe方式的变量，仅在循环内有效，又是一个区别~~

下面是示例：

[root@localhost ~]# cat info
a b c d
[root@localhost ~]# for i in `cat info `;do echo $i;done
a
b
c
d
[root@localhost ~]# i=123;while read i;do echo $i;done<info;echo $i
a b c d

[root@localhost ~]# i=12;cat info |while read i;do echo $i;done;echo $i
a b c d
12
[root@localhost ~]#

另，看到一个网站，专门介绍单行shell命令的，对SA来说，比较有用，url如下：
<a href="http://www.commandlinefu.com/commands/browse">http://www.commandlinefu.com/commands/browse</a>
