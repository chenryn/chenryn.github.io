---
layout: post
title: 快速在 CentOS6 上运行 docker
category: cloud
---

docker 是由著名 PAAS 公司 dotcloud 开源的 linux 容器项目，在此之前，只有 cloudfoundry 下属的 warden 半死不活的慢慢前进着。

不管是 docker 还是 warden，其原理大多是通过 LXC( 即 CGroup 和 namespace 的结合)以及 AUFS 的结合，完成比较彻底的容器虚拟化。这里有个问题：AUFS 不是 linux 官版内核支持的文件系统。所以到现在，各种 PAAS 都是运行在 Ubuntu 系统上，因为只有这个系列的发行版默认打了 AUFS 的补丁。这也严重影响了 PAAS 开源社区的扩容：

1. RedHat 发行版系列才是企业用户最多的 linux 发行版；
2. Debian 社区已经宣布在未来会放弃默认打 AUFS 补丁的做法。

docker 目前已经在积极准备将代码 port 到 BtrFS 上以备未来，不过在此之前，我们还是可以通过自己打补丁的方式，在 RedHat 系列上尝试 docker 的。目前社区已经有很多尝试：

1. [Installing Docker on Fedora 18](http://neh.al/?p=1)
2. [Installing Docker on Centos 6](http://blog.rage.net/2013/08/04/installing-docker-on-centos-6/)
3. [files needed to build RPMs for the dependencies of docker](https://github.com/sciurus/docker-rhel-rpm)
4. [chef-docker](https://github.com/failshell/chef-docker)
5. [Installing Dockerio on Centos6.4-64bit](http://nareshv.blogspot.in/2013/08/installing-dockerio-on-centos-64-64-bit.html)

其中，包括有三种内核，源代码编译支持3.8的，spec编译支持3.10的，以及已经打包完成的3.2的。

我已经尝试过在 Fedora19 上通过源代码编译，似乎内核从3.8到3.10有些变化，编译失败了。(但是尝试过编译3.8的确实没问题)

下面通过最简单的已经打包完成的3.2内核来快速部署 docker 到 CentOS6 上，以便尝鲜：

```bash
rpm -e kernel-firmware
rpm -i http://get.docker.io/kernels/kernel-3.2.40_grsec_dotcloud-4.x86_64.rpm
/sbin/dracut --add-drivers dm-mod --add-drivers linear "" 3.2.40-grsec-dotcloud
grub-install /dev/sda1
echo "blacklist evbug" >> /etc/modprobe.d/blacklist.conf
echo "kernel.grsecurity.chroot_caps = 0" >> /etc/sysctl.conf
echo "sysctl kernel.grsecurity.chroot_caps=1" >> /etc/rc.local
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
mkdir /cgroup
echo "none /cgroup cgroup defaults 0 0" >> /etc/fstab
cat >> /boot/grub/grub.conf<<EOF
title CentOS (3.2.40_grsec_dotcloud-4.x86_64)
	root (hd0,0)
	kernel /boot/vmlinuz-3.2.40-grsec-dotcloud ro root=LABEL=/ rd_NO_LUKS rd_NO_LVM LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto  KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM selinux=0
	initrd /boot/initramfs-3.2.40-grsec-dotcloud.img
EOF
reboot
```

内核的更新就是这些，记住这个包不支持 selinux，所以启动项里要加上 `selinux=0`。

然后重启登录重启并选择了新内核的主机，继续安装一些依赖工具：

```bash
wget "ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home%3A/awk2007%3A/fixes/Fedora_17/src/aufs-util-9999-14.1.src.rpm"
sudo yum install glibc-static
rpmbuild --rebuild aufs-util-9999-14.1.src.rpm
rpm -U /root/rpmbuild/RPMS/x86_64/aufs-util-9999-14.1.x86_64.rpm
wget ftp://ftp.univie.ac.at/systems/linux/dag/redhat/el6/en/x86_64/dag/RPMS/lxc-0.8.0-1.el6.rf.x86_64.rpm
wget http://apt.sw.be/redhat/el6/en/x86_64/dag/RPMS/lxc-libs-0.8.0-1.el6.rf.x86_64.rpm
rpm -U lxc-0.8.0-1.el6.rf.x86_64.rpm lxc-libs-0.8.0-1.el6.rf.x86_64.rpm
```

然后下载 docker 的二进制文件运行，用源代码的话比较麻烦，docker 是用 golang 写的……

```bash
wget http://get.docker.io/builds/Linux/x86_64/docker-latest.tgz
tar xzf docker-latest.tgz
cd docker-latest
```

启动 docker 进程，输出如下：

    [root@localhost docker-latest]# ./docker -d &
    2013/08/24 18:24:18 WARNING: You are running linux kernel version 3.2.40-grsec-dotcloud, which might be unstable running docker. Please upgrade your kernel to 3.8.0.
    2013/08/24 18:24:18 Listening for HTTP on /var/run/docker.sock (unix)

然后就可以通过 docker 命令运行了，示例及输出如下所示：
    
    [root@localhost docker-latest]# ./docker run -i -t busybox /bin/sh
    2013/08/24 18:24:30 POST /v1.4/containers/create
    2013/08/24 18:24:30 POST /v1.4/images/create?fromImage=busybox&tag=
    Pulling repository busybox
    
    Pulling image e9aa60c60128cad1 (latest) from busybox
    Pulling e9aa60c60128cad1 metadata
    Pulling e9aa60c60128cad1 fs layer
    Downloading 2.284 MB/2.284 MB (100%)
    2013/08/24 18:28:37 POST /v1.4/containers/create
    2013/08/24 18:28:37 POST /v1.4/containers/cdf0feaf24a9/start
    2013/08/24 18:28:37 POST /v1.4/containers/cdf0feaf24a9/resize?h=27&w=121
    2013/08/24 18:28:37 POST /v1.4/containers/cdf0feaf24a9/attach?logs=1&stderr=1&stdin=1&stdout=1&stream=1
    BusyBox v1.19.3 (Ubuntu 1:1.19.3-7ubuntu1.1) built-in shell (ash)
    Enter 'help' for a list of built-in commands.
    
    / # 
    / # ls
    bin    dev    etc    lib    lib64  proc   sbin   sys    tmp    usr
    / # cd /root
    /bin/sh: cd: can't cd to /root

可以看到，现在登录进来是不能切换目录到 root 家目录的。

docker 已经运行起来了，更多实例，就可以看着 docker.io 上的[文档](http://docs.docker.io/en/latest/examples/)慢慢进行了
