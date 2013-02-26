---
layout: post
title: sed使用
date: 2009-11-03
category: bash
tags:
  - sed
---

shell这东西，只有活逼到手头上了，才知道应该去学什么。
比如有客户要求修改/home/squid/share/errors/Simplify_Chinese/里所有的错误页面转向到他们自己专用的界面去，七八个节点，几十台服务器，几百个文件，一个一个vi编辑，多可怕。只好现学现卖sed，目前发现两种办法：

1、find+sed
比如这样：
find . -name "*.html" -exec sed -i "s/eht/the/g" {} ;
用exec传输find的结果给sed，{}是集合的意思；

2、sed+grep
比如这样：
sed -i "s/eht/the/g" `grep eht -rl /test`
这个-rl参数，有时间研究一下。

或者这样：
grep "abc" * -R | awk -F: '{print $1}' | sort | uniq | xargs sed -i 's/abc/abcde/g'

awk -F:的意思是指定:为列的分隔符，sort排序，uniq删除重复行，最后用xargs传输大量数据给sed。

说到xargs，比如曾经有一次/var/spool/clientmqueue目录占用了大量磁盘空间，但其中的文件都是4.0K，数量及其多，单纯用rm，无法达到目的，就得用ls | xargs rm -f才行。

