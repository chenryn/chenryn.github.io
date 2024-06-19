---
layout: post
theme:
  name: twitter
title: 引号的魔力
date: 2009-12-04
category: bash
tags:
  - awk
---
```bash
[root@neteasesquid1 ~]# i=1.2.3.4;awk -v OFS="tt" 'BEGIN{print '"$i"',"'"$i"'","'$i'",""'$i'""}'
1.20.30.4
1.2.3.4
1.2.3.4
1.20.30.4
```

以前用awk调用shell变量时，一般都是文字字符串，看不出什么问题来；今天突然用上ip，发现输出结果显示不正常。于是做了如上实验。
但是原因嘛，还是不知道……
继续做下一个实验：
```bash
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.2.3.4"|awk '/'"$i"'/{print}'
1.2.3.4
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.2.3.4"|awk '/"'$i'"/{print}'
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.2.3.4"|awk '/'"$i"'/{print "'$i'"}'
1.2.3
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.2.3.4"|awk '/'"$i"'/{print '"$i"'}'
1.20.3
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.20.3.4"|awk '/'"$i"'/{print}'
[rcl@ubuntu:/win/learning/myshell]$ i=1.2.3;echo "1.20.3.4"|awk '/"'$i'"/{print}'
```
所以最终结果，在regex里，awk引用shell变量是'"$i"'，而在'{}'里则要写成"'$i'"。乱呀……
