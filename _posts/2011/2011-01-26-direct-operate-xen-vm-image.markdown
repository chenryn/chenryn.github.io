---
layout: post
theme:
  name: twitter
title: 直接操作xen虚拟机镜像的办法
date: 2011-01-26
category: cloud
tags:
  - xen
---

一台xen虚拟机，root密码忘记了，必须进入single模式修改root密码。步骤很熟练，xm shutdown domain &amp;&amp; xm create -c domain——但是出问题了——没出现grub的启动界面，直接进入系统启动过程了！

无法从正常操作流程上搞定，那么换一个思路，直接操作镜像文件（谢天谢地，还好是虚拟机），采用loop方式挂载镜像，然后上去改文件好了~

方法如下：

mount -o loop,offset=32256 /xen/disk.img /mnt
然后看/mnt/下的grub.conf，timeout=0，修改成timeout=5，保存退出。umount /mnt后重新使用xm cre -c就可以看到grub界面了~~

现在解释一下这个offset=32256是怎么来的。因为如果不加这串会报出“mount: you must specify the filesystem type”错误。

1、先file确定img文件，如下：
```bash[root@localhost xen]# file /xen/cvs_backup
/xen/cvs_backup: x86 boot sector;
partition 1: ID=0x83, active, starthead 1, startsector 63, 208782 sectors;
partition 2: ID=0x8e, starthead 0, startsector 208845, 62701695 sectors, code offset 0x48```
可以看到这个镜像文件其实被格式化成了两个分区，其中第一个分区的起始块位置是63；
2、用fdisk确定具体的units，如下：
```bash[root@localhost xen]# fdisk -lu /xen/cvs_backup
last_lba(): I don't know how to handle files with mode 81ed
You must set cylinders.
You can do this from the extra functions menu.
Disk /xen/cvs_backup: 0 MB, 0 bytes
255 heads, 63 sectors/track, 0 cylinders, total 0 sectors
Units = sectors of 1 * 512 = 512 bytes
Device Boot      Start         End      Blocks   Id  System
/xen/cvs_backup1   *          63      208844      104391   83  Linux
/xen/cvs_backup2          208845    62910539    31350847+  8e  Linux LVM
Partition 2 has different physical/logical endings:
phys=(1023, 254, 63) logical=(3915, 254, 63)```
可见每个块的大小是512字节。那么虚拟机镜像文件对应的真实起始字节位置就是63*512=32256了。
