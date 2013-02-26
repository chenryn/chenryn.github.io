---
layout: post
title: reiserfs和xfs的inode测试
date: 2011-04-13
category: testing
tags:
  - xfs
  - reiserfs
---

某应用的碎文件生成太多，大量消耗inode，不得不做迁移调整。
原先的使用的NetApp存储，虽然可以调节inode，但是有一个上限，最高就是40000000——说实话真的挺小的啊~~
一个同样大小的普通服务器ext3文件系统，在没有强行指定的情况下，inode都有将近3个亿，是netapp的7倍。
了解了一下ext3文件系统在分区时指定inode最大可用数的情况，大致可以理解为小于可用空间大小/256。详细分析测试情况见：http://blog.wgzhao.com/2008/04/13/how-much-inodes-do-you-need.html，大意是inode个数由block大小和单个inode的字节决定。理论上最小block是1024，实际（采用-N强行指定的话）可能是256左右。

之前在做sersync的时候，发现开启xfs支持就可以对netapp使用inotify功能。因此可以认为netapp使用是（至少在inode上）类似xfs的文件系统。最终决定测试一个reiserfs和xfs在inode方面的情况——这两个文件系统都是非分布式的动态inode的文件系统。
RHEL5默认是不支持这两个fs的。需要plus一下。方法见http://www.gnutoolbox.com/reiserfs-centos/和http://wiki.centos.org/AdditionalResources/Repositories/CentOSPlus的说明。一步一步照做即可。
随后在vmware上添加一块10G的硬盘sdb，fdisk分区成sdb1和sdb2，分别mkfs.reiser和mkfs.xfs两个分区，挂载在/mnt1和/mnt2上。
这个时候df -h和df -i查看如下：
[root@localhost ~]# df -i
Filesystem            Inodes   IUsed   IFree IUse% Mounted on
/dev/sda3            1240320  144694 1095626   12% /
/dev/sda1              26104      40   26064    1% /boot
/tmpfs                 64314       1   64313    1% /dev/shm
/dev/sdb1                  0       0       0    -  /mnt1
/dev/sdb2             562240    2368  559872    1% /mnt2
[root@localhost ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/sda3              19G  4.8G   14G  27% /
/dev/sda1              99M   17M   77M  18% /boot
/tmpfs                252M     0  252M   0% /dev/shm
/dev/sdb1             471M  33M  438M   7% /mnt1
/dev/sdb2             545M   28M  517M   6% /mnt2
另开窗口，分别运行for((i=1;i<562240;i++));do touch /mnt1/a_$i;done和for((i=1;i<562240;i++));do touch /mnt2/b_$i;done——为了加速，实际开了四个窗口，每个命令都是同时运行两个。
一段时间后，mnt2的终端显示No space。于是中止。
此时df -i和df -h的结果如下：
[root@localhost ~]# df -i
Filesystem            Inodes   IUsed   IFree IUse% Mounted on
/dev/sda3            1240320  144694 1095626   12% /
/dev/sda1              26104      40   26064    1% /boot
/tmpfs                 64314       1   64313    1% /dev/shm
/dev/sdb1                  0       0       0    -  /mnt1
/dev/sdb2             124032  123397     635  100% /mnt2
[root@localhost ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/sda3              19G  4.8G   14G  27% /
/dev/sda1              99M   17M   77M  18% /boot
/tmpfs                252M     0  252M   0% /dev/shm
/dev/sdb1             471M   60M  411M  13% /mnt1
/dev/sdb2             545M  545M  144K 100% /mnt2
可以发现，xfs的空间没有变化（说这句是因为ext3在强制inode数变大的时候，可用空间会变小），但inode总数“神奇”的缩水了4倍！！
继续等待，直到mnt1的for循环执行完成，这时候df -h结果如下：[root@localhost ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/sda3              19G  4.8G   14G  27% /
/dev/sda1              99M   17M   77M  18% /boot
/tmpfs                252M     0  252M   0% /dev/shm
/dev/sdb1             471M  134M  338M  29% /mnt
根据最后的结果算471*1024/562240/2=0.43K， 545*1024/124032=4.5K。看来对于空文件，reiserfs很压缩，而xfs则老老实实的做block了。
