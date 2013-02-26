---
layout: post
title: linux更改时区
date: 2010-10-09
category: linux
---

linux上的时间，一般用定时ntpdate或者守护ntpd服务来保持正确。不过有时候会发现系统时间显示不是我们熟悉的CST，而是莫名其妙的其他地方。比如EDT什么的，ntpdate的时候，可不会自己辨别时区的~~
那么就要自己手动更改了。
办法很多，第一：
/usr/bin/tzselect命令，然后采用一问一答的方式完成配置，这个命令其实就是一个shell脚本，利用select和case命令完成交互，从/usr/share/zoneinfo/中获取指定的文件完成操作。
第二：
既然知道了tzselect的操作过程，也就可以自己来干这件事情：直接进入/usr/share/zoneinfo目录，找到需要的文件，比如cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime即可；
第三：
各linux发行版都会有一些自己定制的配置工具，最有名的比如红帽的setup~
对于时区设置，也有这种工具，redhat系列有timeconfig，debian系列有dpkg-reconfigure tzdata。
