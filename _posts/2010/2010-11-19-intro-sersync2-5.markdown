---
layout: post
title: sersync2.5试用~
date: 2010-11-19
category: linux
tags:
  - inotify
---

之前采用 inotify-tools 来触发 purge，实际运行中碰上一些问题：

1、因为一个文件的更新，可能伴随着 `create`、`modify`、`close_write` 等等过程，而文件稍大一些，甚至就有连续的 `modify` 出现。于是一个文件的更新，通过管道发送的 purge 请求经常可以看到三四个！如果量不大的情况下，倒也没什么，可如果更新比较频繁的情况下，再翻上三四倍，任务就比较拥挤了。

2、cms 程序通常是通过 ftp 等方式，将页面上传的文件 move 到指定位置。而 ftp 本身在接受过程中也会产生名叫 `.pureftpd-upload.****` 的临时文件。

第二个倒可以在管道后面再 grep 一次解决，但第一个问题在管道这种流形式的简单处理中就没办法了。预想了几个办法，先一个是记录日志，然后每次管道接受时比对日志中最近十条是否有重复，不过这么频繁的读写日志文件，也会很郁闷~；后一个是把日志文件转进内存去，即管道获取的信息 push 进一个 hash，然后 sleep 后再 poll 这个 hash 出来，不过 shell 没有 hash，就得把简单的 shell 重写成比较复杂的 perl 了……

今天刚想起来半年前曾经看到过金山逍遥运维部开源的一个项目，也是基于 inotify 完成的。去翻来看看，很好很强大，感觉完全能满足我目前的想法。

项目网址：<http://code.google.com/p/sersync/>

提供了 bin 和 src 两个版本，直接下 bin 来用：

```bash
wget http://sersync.googlecode.com/files/sersync2.5_64bit_binary_stable_final.tar.gz
tar zxvf sersync2.5_64bit_binary_stable_final.tar.gz
cd GNU-Linux-x86/
```

很简单，只有两个文件，一个是程序，一个是 xml 配置文件。配置包括 debug 模式、xfs 支持、过滤器配置（默认已过滤`^.`和`~$`）、inotify 监听（推荐是创建目录、完成输入和移动）、本地监听路径和 rsync 远程主机（ip，rsync 模块名、用户名密码）、失败重试及日志、多次失败后的定时任务、插件（通过socket 向远程主机传输 inotify 日志、通过 http 向 cdn 的 api 发送 purge 请求、调用外部命令处理文件）。

本来直接就有 purge 功能，可惜我的环境下域名比较多，目前的功能上只能对 url 做 regex，不能反引用到 domain 上。所以是写个 shell，然后采用 command 插件传递参数~

先最简单的实验，写个write.sh如下：

```bash
#!/bin/sh
echo $1 >> $0.log
```

然后修改xml如下句：

```xml
    <param prefix="GNU-Linux-x86/write.sh" suffix="" ignoreError="true"/>
```

运行 `GNU-Linux-x86/sersync2 -d -m command` 即可后台运行 command 插件且不启用 rsync。

然后 `tailf write.sh.log` 看，果然每条 url 都不重复了~~

（看了作者周洋的 blog，其中提到文件如果比较大，更新完成时间超过一定值，也会导致队列重复，我猜估计思路和我的第二种想法应该是类似的。）

另，`sersync -h` 可以看到其固定修改 sysctl 如下：

```bash
echo 50000000 > /proc/sys/fs/inotify/max_user_watches
echo 327679 > /proc/sys/fs/inotify/max_queued_events
```

据周洋的说法是 inotify 最多只能监听到五千万个文件夹~~在我的环境下，1300 万 inode，add watch 就花了1个多小时……
