---
layout: post
theme:
  name: twitter
title: inotify使用一例
date: 2010-11-04
category: linux
tags:
  - inotify
---

在对一个大磁盘进行inotify监听时，爆出如下错误：

Failed to watch /mnt/;
upper limit on inotify watches reached!
Please increase the amount of inotify watches allowed per user via `/proc/sys/fs/inotify/max_user_watches'.

cat一下这个文件，默认值是8192；df -i看看inode数量，远远大过这个值~

echo 8192000 > /proc/sys/fs/inotify/max_user_watches即可~
