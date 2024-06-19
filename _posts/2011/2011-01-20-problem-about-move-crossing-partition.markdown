---
layout: post
theme:
  name: twitter
title: 图片分离小故障一例
date: 2011-01-20
category: linux
---

有需求对某应用的图片和页面内容进行拆分。计划进行的很顺利，存储设备上成功分成了/vol/html和/vol/image，然后分别挂载在应用服务器上发布为html.domain.com和image.domain.com。但在恢复应用运行后出现一个问题：新图片的上传总是提示失败。

查看服务器上的日志，还好jvm-default.log记录的相当详细。上传程序首先在html.domain.com/dynamic/domain*/下创建一个tmp/，上传的图片*.jpg和缩略图s_*.jpg就暂存在该tmp/下。然后再mv到相应的image.domain.com/domain*/$date下。图片上传到tmp是成功的，特意选择一个比较偏僻的domain9，由系统来新建这个image.domain.com/domain*/$date，也成功了。

开发同事去检查程序，试图提供更详细的报错信息，然后发现报错的地方写的是if (!TmpPicReNameNewPic || !TmpSmallPicReNameNewSmallPic ) {*};

于是想到有一种可能，虽然存储还是同一个存储，但是分成了两次mount，或许linux系统就将该存储当成了两个磁盘，而rename方法在linux的实现是不可以跨磁盘操作的。见man文档：
  oldpath and newpath are not on the same mounted filesystem.
  (Linux permits a filesystem to be mounted at multiple points, but rename(2)
  does not work across different mount points, even if the same filesystem is
  mounted on both.)
解决办法有两种，一种是修改程序，把rename改成真正的mv(即先cp，然后rm) ；另一种是想办法只挂载一次存储。考虑到这个猜测有可能不正确，折腾程序比较麻烦，正好这次图文拆分也不是彻底的分离到不同服务器上，而是存储上的两个路径而已。决定先mount NetAppIp:/vol/ /mnt;ln -s /mnt/html /www/html.domain.com;ln -s /mnt/image /www/image.domain.com；重启服务再测试上传，果然成功了！
