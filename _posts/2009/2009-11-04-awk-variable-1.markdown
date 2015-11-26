---
layout: post
title: awk变量（续）
date: 2009-11-04
category: bash
tags:
  - awk
---

上回用的是-F（其实如果标准化一点，在BEGIN{}里还可以区分成输入输出的FS和OFS）、NR（当前行数）、NF（当前域数）和$0（当前行全部内容），如果是一般的处理，这些差不多也就够了。

今天再学两个东东，RS和RT。

RS，也就是行分割符；RT，咋翻译，我看了好一会man文档也没搞懂，大概的说，如果RS是单字符的话，RT==RS，如果RS用了正则表达式的话，RT就是当前行RS的内容——也不知道这么说是否准确，目前就理解到这步。注意：RT是GNU awk的扩展功能，所以可能有些平台上不支持。呵呵~~

说实话，理解这个RS颇是花了我不少脑细胞去想象。直到看到一个网页，大概意思是这样：
假如test内容是：
123 456
abc def
ABC DEF
654 321
那么对于类UNIX系统来说，test文件内容其实是123 456\nabc def\nABC DEF\n654 321
awk默认的RS，就是"\n"（默认FS是" "和"\t"即tab），每碰见一个RS，awk就停下来，输入space处理。假如一直没有RS，就输完全部文件为止。
如果在BEGIN{}里另外定义RS的话，要注意的是，这个时候"\n"还不会成为字符出现，而是自动转为默认的FS。

对test的实验过程如下：
```bash
[root@raocl ~]# cat test
123 456
abc def
ABC DEF
654 321
[root@raocl ~]# awk '{print $1}' test
123
abc
ABC
654[root@raocl ~]# awk 'BEGIN{RS="ABC"}{print $1}' test
123
DEF
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS=" "}{print $1}' test
123
DEF
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="\n"}{print $1}' test
123 456
DEF
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="abc"}{print $1}' test
123 456
DEF
654 321
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="\t"}{print $1}' test
123 456
abc def
DEF
654 321
```
我是似乎明白了，不知道路过我博客的同仁们明白了么？

然后说RT，还是用实验来证明吧：
```bash
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="\t"}{print $1,RT}' ts
123 456
abc def
ABC
DEF
654 321
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="\t"}{print $1,RS}' ts
123 456
abc def
ABC
DEF
654 321
ABC
```
对了，还记得上回取上一行用的办法么？我再试试：
```bash
[root@raocl ~]# awk 'BEGIN{RS="ABC";FS="\t"}{print $1,x}{x=RT}' ts
123 456
abc def
DEF
654 321
ABC
```
也是打印出来上一行的RT了。
这个都是同一的字符做RS，下面转载一个复杂的正则匹配RS的例子：
```bash
[root@mip blog]# cat TR_file
Sun Jan 2 07:42:56 2000
Database mounted in Exclusive Mode
Completed: ALTER DATABASE MOUNT
Sun Jan 2 07:42:56 2000
Database tested in Exclusive Mode
Completed: ALTER DATABASE MOUNT
abc Jan 2 12:42:56 2000
Database mounted in Exclusive Mode
Completed: ALTER DATABASE MOUNT
Sun Jan 2 23:00:00 2009
Database mounted in Exclusive Mode
Completed: ALTER DATABASE MOUNT
[root@mip blog]# awk -v RS='[[:alpha:]]+ [[:alpha:]]+ [0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]' '$0~/mounted/{print s}{s=RT}'
RT_file
Sun Jan 2 07:42:56
abc Jan 2 12:42:56
Sun Jan 2 23:00:00
```

