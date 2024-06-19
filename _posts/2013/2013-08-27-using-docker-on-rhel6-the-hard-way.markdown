---
layout: post
theme:
  name: twitter
title: 编译最新 3.10 内核在 RHEL6 上支持 Docker
category: cloud
tags:
  - linux
---

之前在 Fedora19 上试图自己通过编译 3.10 内核的方式来完成 aufs 的支持，但是一直有问题，哪怕同样的步骤，github 上其他人都可以，只能怀疑是我个人电脑问题了。不过后来通过 SPEC 方式完成了最终测试，感谢 sciurus 童鞋的[项目](https://github.com/sciurus/docker-rhel-rpm)。

部署过程如下：

```bash
# 安装这个包以便使用 mock 命令在 chroot 环境下打包
yum install -y fedora-packager
# 下载我的而不是原作者的，因为里面 aufs 和 lxc 的下载链接都已经更新了，原来的404了
git clone https://github.com/chenryn/docker-rhel-rpm.git

spectool -g -C docker docker/docker.spec 
mock -r epel-6-x86_64 --buildsrpm --spec docker/docker.spec --sources docker --resultdir output
mock -r epel-6-x86_64 --rebuild --resultdir output output/docker-0.6.0-1.el6.src.rpm 

spectool -g -C lxc lxc/lxc.spec
mock -r epel-6-x86_64 --buildsrpm --spec lxc/lxc.spec --sources lxc --resultdir output
mock -r epel-6-x86_64 --rebuild --resultdir output output/lxc-0.8.0-3.el6.src.rpm

spectool -g -C kernel-ml-aufs kernel-ml-aufs/kernel-ml-aufs-3.10.spec
mock -r epel-6-x86_64 --buildsrpm --spec kernel-ml-aufs/kernel-ml-aufs-3.10.spec --sources kernel-ml-aufs --resultdir output
mock -r epel-6-x86_64 --rebuild --resultdir output output/kernel-ml-aufs-3.10.5-1.el6.src.rpm

cd output
yum localinstall --nogpgcheck kernel-ml-aufs-3.10.5-1.el6.x86_64.rpm lxc-0.8.0-3.el6.x86_64.rpm lxc-libs-0.8.0-3.el6.x86_64.rpm docker-0.6.0-1.el6.x86_64.rpm

echo 'none                    /sys/fs/cgroup          cgroup  defaults        0 0' > /etc/fstab
reboot
```

kernel 文件来自 RHEL，不过我试了下，在我的Fedora19上也正常可用。3.10.5 和 3.2 相比，第一 3.10 将会是未来一段时间内 kernel 的主线支持；第二 docker 官方说在 3.8 之前有点小 bug 可能会被触发。

