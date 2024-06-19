---
layout: post
theme:
  name: twitter
title: linux内核编译升级
date: 2011-02-14
category: linux
---

N年没更新的ipvsadm终于在今年春节前更新了，正好手头有lvs的任务，赶紧试试。lvs上说的很清楚，ipvsadm的1.2.26版仅工作于linux kernel2.6.28以上版本。所以首先要把现有的2.6.18的linux kernel升级。

1. 从kernel.org上获取高版本的kernel原文件：
wget http://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.37.tar.bz2
tar jxvf linux-2.6.37.tar.bz2 -C /usr/src

2. 做好源代码连接
ln -s /usr/src/linux-2.6.37 /usr/src/linux

3. 开始选择编译参数
cd /usr/src/linux
make mrproper #这一步是清除可能存在的其他内核编译结果
make menuconfig #采用字符界面选择，初次操作的就别改什么了。
make bzImage #生成vmlinuz
make modules
make modules_install #生成模块
make install  #把生成的System.map/initrd/vmlinuz等都mv到/boot下，并修改grub配置

4. 重启
sed -i 's/default=1/default=0/' /boot/grub/menu.lst
reboot

嗯，很好，然后等待，十分钟过去，依然ping不通(这么简单就搞定，我也懒得写这篇博文啦)……赶紧接显示器看看进展。启动界面停留在如下画面：
Unable to access resume device (LABEL=SWAP-sda9)
mount : could not find filesystem '/dev/root'
setup other filesystem
setting up now root fs
set up root :moving /dev faild:No such file or directory
no fstab.sys,mounting inernal defaults
setuproot:error mounting /proc :No such file or directory
setuproot:error mounting /sys:No such file or directory
switching to new root and running init
umounting old /dev
umounting old /proc
umounting old /sys
switchroot : mount faild : No such file or directory
kernel panic:not syncing :attempted to kill init
call trace
sysfs系统无法挂载……原来linux kernel2.6.3*中，在menuconfig中有个很重要的选项：
enable deprecated sysfs features which may confuse old userspace tools
help文档对这个选项的解释是：“<strong>Do not say Y, if the original kernel, that came with your distribution, has this option set to N.</strong>”

<span style="color: #ff0000;">很不幸，RHEL5的/usr/src/kernels/2.6.18-92.el5-x86_64/.config中压根就没有CONFIG_SYSFS_DEPRECATED这行……所以必须选上这个选项。</span>

选择老内核进入系统，重新来过一次编译，除了这个选项以外一切相同。重启就成功进入了！
