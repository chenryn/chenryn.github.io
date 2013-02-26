---
layout: post
title: sersync2.5试用~
date: 2010-11-19
category: linux
tags:
  - inotify
---

之前采用inotify-tools来触发purge，实际运行中碰上一些问题：

1、因为一个文件的更新，可能伴随着create、modify、close_write等等过程，而文件稍大一些，甚至就有连续的modify出现。于是一个文件的更新，通过管道发送的purge请求经常可以看到三四个！如果量不大的情况下，倒也没什么，可如果更新比较频繁的情况下，再翻上三四倍，任务就比较拥挤了。

2、cms程序通常是通过ftp等方式，将页面上传的文件move到指定位置。而ftp本身在接受过程中也会产生名叫.pureftpd-upload.****的临时文件。

第二个倒可以在管道后面再grep一次解决，但第一个问题在管道这种流形式的简单处理中就没办法了。预想了几个办法，先一个是记录日志，然后每次管道接受时比对日志中最近十条是否有重复，不过这么频繁的读写日志文件，也会很郁闷~；后一个是把日志文件转进内存去，即管道获取的信息push进一个hash，然后sleep后再poll这个hash出来，不过shell没有hash，就得把简单的shell重写成比较复杂的perl了……

今天刚想起来半年前曾经看到过金山逍遥运维部开源的一个项目，也是基于inotify完成的。去翻来看看，很好很强大，感觉完全能满足我目前的想法。

项目网址：<a href="http://code.google.com/p/sersync/">http://code.google.com/p/sersync/</a>

提供了bin和src两个版本，直接下bin来用：

wget http://sersync.googlecode.com/files/sersync2.5_64bit_binary_stable_final.tar.gz
tar zxvf sersync2.5_64bit_binary_stable_final.tar.gz
cd GNU-Linux-x86/

很简单，只有两个文件，一个是程序，一个是xml配置文件。配置包括debug模式、xfs支持、过滤器配置（默认已过滤^.和~$）、inotify监听（推荐是创建目录、完成输入和移动）、本地监听路径和rsync远程主机（ip，rsync模块名、用户名密码）、失败重试及日志、多次失败后的定时任务、插件（通过socket向远程主机传输inotify日志、通过http向cdn的api发送purge请求、调用外部命令处理文件）。

本来直接就有purge功能，可惜我的环境下域名比较多，目前的功能上只能对url做regex，不能反引用到domain上。所以是写个shell，然后采用command插件传递参数~

先最简单的实验，写个write.sh如下：

#!/bin/sh
echo $1 >> $0.log

然后修改xml如下句：<param prefix="GNU-Linux-x86/write.sh" suffix="" ignoreError="true"/>

运行GNU-Linux-x86/sersync2 -d -m command即可后台运行command插件且不启用rsync。

然后tailf write.sh.log看，果然每条url都不重复了~~

（看了作者周洋的blog，其中提到文件如果比较大，更新完成时间超过一定值，也会导致队列重复，我猜估计思路和我的第二种想法应该是类似的。）

另，sersync -h可以看到其固定修改sysctl如下：
echo 50000000 > /proc/sys/fs/inotify/max_user_watches
echo 327679 > /proc/sys/fs/inotify/max_queued_events

据周洋的说法是inotify最多只能监听到五千万个文件夹~~在我的环境下，1300万inode，add watch就花了1个多小时……
