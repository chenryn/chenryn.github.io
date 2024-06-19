---
layout: post
theme:
  name: twitter
title: linux小报错一例
date: 2011-03-17
category: linux
---

需要给某台服务器加内存，准备关机的时候，却一直报错。考虑直接断电危害比较大，还是找找原因，报错如下：
shutdown: timeout opening/writing control channel /dev/initctl 
init: timeout opening/writing control channel /dev/initctl 
从messages日志里没有发现任何附加信息。只能求助百度。好在解答很多：
是原有的initscripts和SysVinit找不到了导致的。
传上去initscripts-8.45.19.EL-1.x86_64.rpm和SysVinit-2.86-14.x86_64.rpm两个包，rpm -ivh安装。
重新poweroff还是报错；但强制-f跳过shutdown过程后，成功了。稍后再启动设备，试着再敲一次poweroff，这次就不报错，成功关机了。
