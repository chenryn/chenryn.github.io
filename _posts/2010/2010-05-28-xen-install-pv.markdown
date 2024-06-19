---
layout: post
theme:
  name: twitter
title: xen安装PV
date: 2010-05-28
category: cloud
tags:
  - xen
---

闲来无事，打算自己安装一个xen虚拟机，看了看文档，知道必须采用网络安装方式（NFS/FTP/HTTP），于是随手去搜狐镜像站下了一个iso下来挂载用。
不过virt-install一直报错。
首先是：
    mount.nfs: Input/output error
    umount: /var/lib/xen/xennfs.jfkgaj: not mounted
    ERROR:  Unable to mount NFS location!
诡异了，我手动都能mount上远端的nfs了~~百度没结果，谷大婶出动，原来这边也要启动portmap才行。
下一步，继续出错：
    ERROR:  Invalid NFS location given: [Errno 2] No such file or directory: '/var/lib/xen/xennfs.JjVbzO/images/xen/vmlinuz'
没有文件？返回nfs上去看，嗯，目录下只有一个LiveCD，一个isolinux。咋回事呢？
又返回搜狐去翻目录，在os/下看到了images/xen/vmlinuz，难道要把整个os/目录下载了？可我记得这个目录就应该是iso挂载后的东西呀~
返回isos/去看，终于发现一个极弱智的问题：目录下有LiveCD和bin-DVD两个镜像，我直接点了最顶上的一个，也就是LiveCD那个……
赶紧重新下载……
之后一路顺利。
A机(10.10.10.10)上：
```bash
wget http://mirrors.sohu.com/centos/5.4/isos/x86_64/CentOS-5.4-x86_64-bin-DVD.iso -c
mount -o loop -t iso9660 /cache/CentOS-5.4-x86_64-bin-DVD.iso /mnt
echo '/mnt 10.10.10.0/24(ro,async)'>>/etc/exports
/etc/init.d/portmap start
/etc/init.d/nfs start
```
B机(10.10.10.11)上：
```bash
mkdir /img
dd if=/dev/zero of=/img/test.img bs=1024k count=8k
virt-install --paravirt --file=/img/test.img --name=test --ram=1024 --vcpus=1 --bridge=xenbr0 --bridge=xenbr1 --nographics --location=nfs:10.10.10.10:/mnt
```
（半虚拟化、虚拟机安装位置、虚拟机名、内存、CPU、桥接网卡*2、文本模式、安装源）
然后就是很普通的linux安装过程了，填ip，分区云云……选择最小化安装，reboot。
又见报错：
    Restarting system.
    libvir: Xen Daemon error : GET operation failed: 
    Guest installation complete... restarting guest.
    libvir: Xen Daemon error : GET operation failed: 
    libvir: Xen Daemon error : internal error domain information incomplete, missing kernel
    Entity: line 30: parser error : Opening and ending tag mismatch: os line 5 and domain
    </domain>
             ^
    Entity: line 31: parser error : Premature end of data in tag domain line 1
哪里有问题呢？
随手xm list，发现居然有一个名叫test的的guestOS，赶紧console一看，完全能用！！
不太相信的关机，重新create了一次，还是没问题！
把在/etc/xen下自动生成的test文件mv进/etc/xen/auto下，再把整个宿主机一重启，几分钟后重登陆一看，testOS也已经启动起来能用了。完成！
 
 
