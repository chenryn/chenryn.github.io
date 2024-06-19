---
layout: post
theme:
  name: twitter
title: xen的dom0内存设置
date: 2010-12-10
category: cloud
tags:
  - xen
---

公司测试环境使用了xen来提供大批逻辑隔离的服务器供内部调测使用。随着应用系统和同事人数的增加，虚拟机数量越来越多，原先每台server开两三个vm已经吃紧，遂要增加新的vm。cp相应的img后，启动却失败了。

连上server看了一下具体的报错和系统信息，server的BIOS上识别出了1G内存，free命令的mem-total是491MB，xm li看到dom0的mem正是491M，而dom1、dom2各255M。

修改/etc/grub.conf，在kernel /xen.gz-2.6.18-8.el5后面加上dom0_mem=128M。reboot之后再启动第三台vm，OK！

另：按照一般经验，一台2G的server，dom0最低使用mem在128-256M，单个vm的mem最低为64M(debian)或128M(CentOS)
