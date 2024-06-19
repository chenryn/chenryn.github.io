---
layout: post
theme:
  name: twitter
title: 折腾 awk 内调用 shell 变量
date: 2010-06-07
category: bash
tags:
  - awk
---

在对squid进行目录刷新的时候，一般使用的脚本都是采用for i in `squidclient mgr:objects|grep $1|awk '{print $2}'`;do squidclient -m purge "$i";done的方式。

mgr:objects本来就是一个比较费资源的请求，假如一个200G的cache，这个$i变量该卡多久才能有反应？抑或直接挂掉……

于是把这个稍微改进一下，变成squidclient mgr:objects|awk '/"'$1'"/{system("squidclient -m purge "$2)}'，因为awk对每行进行匹配后，就可以同时作出反应，所以比存一个大变量要好一些。

不过在使用中发现还有一些别的问题。比如碰到http://www.test.com/abc(123).html这样的url的时候，就会出错：

sh: -c: line 0: syntax error near unexpected token `('

url里的括号和awk函数的括号冲突了。所以对$2不能简单引用就完，还得处理。
CU上有人给出如下写法：

awk '{system("squidclient -m purge '''"$2"'''")}'

一试果然可以，试着分解一下这堆引号：

'{system("squidclient -m purge '第一部分，单引号表示里面的内容都传递给awk处理；

'第二部分，shell环境下转义单引号为普通字符；

'"$2"'第三部分，传递给awk，其中第一个"接第一部分的"，完成system函数的命令部分，其中包括了第二部分的普通字符'；

'第四部分，shell环境下转义单引号为普通字符；

'")}'第五部分，传递给awk，其中"接第三部分的第二个"，其中包含了第四部分的普通字符'；

合在一起，就给替换好的$2加上了一对''，然后通过system函数传递给shell执行。OK~~

