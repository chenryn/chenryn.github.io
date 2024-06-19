---
layout: post
theme:
  name: twitter
title: awk内置函数
date: 2009-11-04
category: bash
tags:
  - awk
---

前几篇说awk变量，今天说函数。

看到内置变量的中文翻译如下：

ARGC命令行参数个数 AGRV命令行参数排列 ENVIRON支持队列中系统环境变量的使用 FILENAME浏览文件名
FNR浏览文件的记录数 FS输入域分隔符 NF浏览记录的域个数 NR已读的记录数 OFS输出域分隔符 ORS输出记录分隔符
RS控制记录分隔符

index(s,t) 返回s中字符串t的第一位置
[root@raocl ~]# awk 'BEGIN {print index("Sunny","ny")}'
4

length(s) 返回s的长度
[root@raocl ~]# awk 'BEGIN {print length("Sunny")}'
5

match(s,r) 测试s是否包含匹配r的字符串，默认带两个变量RSTART、RLENGTH，分别是开始位置和占用长度
[root@raocl ~]# echo 12|awk '$1="J.Lulu"{print match($1,"u"),RSTART,RLENGTH}'
4 4 1

split(s,a,fs) 以fs为分隔符将s分割输入数组a
[root@raocl ~]# awk 'BEGIN {print split("12#345#6789",myarray,"#"),myarray[2]}'
3 345

substr(s,p) 返回字符串s中从p开始的后缀部分

substr(s,p,n) 返回字符串s中从p开始长度为n的后缀部分
[root@raocl ~]# echo abcdefg|awk '{print substr($0,1,length($0)-4)}'
abc

gsub(r,s,t) 在t中用s替代r（不写t就是$0）
（附：sub()函数只替换第一次出现的位置；另，sub/gsub修改字符串，而substr是生成子串，不修改原串）
[root@raocl ~]# echo abc|awk 'gsub(/ab/,"12",$0)'
12c

