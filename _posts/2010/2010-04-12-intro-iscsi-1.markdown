---
layout: post
title: iscsi试验（失败，慎入）
date: 2010-04-12
category: linux
---

聊天时听同事提及iscsi。回来后借助百度和谷歌大概了解了一下是网络存储，就赶紧下了软件包作测试。
{% highlight bash %}
wget http://downloads.sourceforge.net/project/iscsitarget/iscsitarget/1.4.19/iscsitarget-1.4.19.tar.gz
tar zxvf iscsitarget-1.4.19.tar.gz
cd iscsitarget-1.4.19
make && make install
{% endhighlight %}
就完成了服务器端的安装，然后修改配置文件/etc/iet/ietd.conf，方便起见，就写最基本的三行：

    Target iqn.2010-04.com.test:storage.xvdb1
    Lun 0 Path=/dev/xvdb1,Type=fileio
    Alias Test

启动服务/etc/init.d/iscsi-target start，netstat查看，发现有3260端口的监听了。

然后是客户端，更容易，直接yum install iscsi-initiator-utils就够了。然后启动服务/etc/init.d/iscsid start。

然后链接服务器，iscsiadm -m discovery -t st -p 10.12.13.86，可以搜索到了。不过居然出现两个，分别是服务器内外网ip搜索的值。两个办法。

一个是定义客户端/var/lib/iscsi/iface/ieth0文件如下：

    iface.iscsi_ifacename = ieth0
    iface.net_ifacename = eth0
    iface.hwaddress = default
    iface.transport_name = tcp

然后用iscsiadm -m discovery -t st -p 10.12.13.86 -I ieth0命令搜索；

一个是定义服务端/etc/iet/targets.allow文件如下：

    ALL 10.12.13.0/24

然后/etc/init.d/iscsi-target restart就可以了。

最后搜索结果如下：

    10.12.13.86:3260,1 iqn.2010-04.com.rao:storage.xvdb1

在客户端用iscsiadm -m node -p 10.12.13.86 --targetname iqn.2010-04.com.rao:storage.xvdb1 --login命令，就可以连上磁盘了。然后用fdisk -l命令可以看到如下输出：

    Disk /dev/sda: 750.1 GB, 750153729024 bytes

试验到目前为止一切正常。然后再mount这个sda的时候，赫然提示没有格式化！！
好吧，fdisk /dev/sda然后mkfs.ext3 /dev/sda1再mount /dev/sda1 /mnt。
OK，返回服务器端，mount，居然提示ext3错误~~

再开一台，同样到mount的时候，又一次提示没有格式化。
难道iscsi和nfs不一样，压根不能多客户端同时连接一块磁盘？？？
还是说因为iscsi默认是sda，而虚拟机是xvda，之间有冲突？？？
于是返回谷歌搜索“iscsi xen”，结果看来应该是第一种了。
[xen和iscsi的常见合用](http://www.performancemagic.com/iscsi-xen-howto/index.html)
，是在Domain0上链接iscsi，然后基于不同的target分别create虚拟机模板和虚拟机磁盘，进一步可以保证虚拟平台出问题时，可以迅速的转移到另一个虚拟平台上。
而后看到<a target="_blank" href="http://www.sansky.net/">存储部落</a>中的介绍，iscsi可以同样理解为裸设备，要达到网络共享，需要配套另外的共享软件~比如GFS
 

