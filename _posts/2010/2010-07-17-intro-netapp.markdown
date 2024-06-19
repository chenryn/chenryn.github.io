---    
layout: post    
theme:
  name: twitter
title: 初识NetApp存储    
date: 2010-07-17    
category: linux
tags:
  - NetApp
---    
    
对专门的存储设备实在所知甚少，今天有时间找了找netapp的资料看看，有点基本了解。资料见豆丁：<a href="http://www.docin.com/p-56454923.html">http://www.docin.com/p-56454923.html</a>    
    
从系统运维角度来说，首先关注的是RAID部分，netapp自定义有RAID-DP。这是一个私有的RAID6解决方案，在RAID4的基础上发展而来的。    
RAID4即专有一个同位数据校验盘，原始数据以块大小分割存储；    
RAID5则将同位校验数据和原始数据重新组合，以位大小分割存储；    
RAID6标准是在存放同位校验数据同时，还增加了针对块的校验数据；    
RAID-DP，同时拥有两种校验，并把这两种校验都单独存盘。    
即，RAID-DP，每组至少需要3个盘；而据资料显示，netapp最多支持每组28个盘，默认则是16个。    
    
多个RAID组组成一个Plex，然后plex组成aggregate。从资料上看，aggr中的plex一般不多。这些硬件上的情况，可以用aggr status -r来查看。    
在aggr上，再进行逻辑卷volume的划分，一个flexvol最小20MB，最大16T，可以4K大小的加减；最多可以创建500个flexvol。    
    
然后是使用方式，DAS/NAS/SAN都行，现在在用的是NFS挂载（NAS），以后或许试试iscsi（SAN）。这部分内容看之前相关博文就行。    
    
IO方式，分file和blockI/O两种。    
    
监控方式，netapp自带一些性能监控命令，sysstat、nfsstat、netstat等等。    
    
<hr />在存储设备选择比较时，最经常被提及的一个参数是IOPS，即每秒IO操作数。    
在netapp上运行sysstat命令，看到最前列有个ops/s，峰值高达15k。这个数值被设备方的销售认为是绝对不可能的……    
    
于是抠字眼吧，iops和ops有什么不同呢？有文档说ops叫每秒并发操作数，并不限定是IO。不过作为专业存储设备，基本除了IO也不会有什么别的操作了吧？    
    
正好，因为图省事，我比较喜欢看设备的web界面性能监控页自动画出的柱状图。第二个图就是ops/s的图，图左的文字说明是“Network File Operate per second“，即每秒网络文件操作数。而询问销售，IOPS却是指的block的操作数——区别就在这里！    
    
因为采用NFS挂载存储的方式无法直接观察block的操作监控，最后采用一个估算的办法，统计每秒IO的文件大小，然后除以block的大小，得出每秒IO操作数。    
还是用systat命令，取max的r/s和w/s（KB）值，相加得32k。    
然后用aggr status -b命令，取得block值为4KB，估算得IOPS为8k。    
还是用aggr status -r命令，取得disk的总数为42，估算每块盘的IOPS为180。    
和网上的评论比较，一般测试在170多的时候性能最好，再高就下降。看来这个设备运行在比较悬的状态了——目前CPU监测使用率在95%左右。    
    
存储上的磁盘都是15000转的，在IO发生时，磁盘要转动，机头要移动，都需要时间，开始计算：    
15000/60=250PRS    
1/250=0.004spr=4mspr    
4/2=2ms（磁盘转动耗时RD，最多半圈）    
2+4=6ms（机头寻道时间，百度一下，希捷3.4，日立3.3，都是最快的那种，就按4ms算吧）    
1000/6=167IOPS（按日立那个最快的算是188）    
    
写到最后，在CU上看到一个好帖子，链接如右：<a href="http://bbs.chinaunix.net/thread-1607334-1-1.html">http://bbs.chinaunix.net/thread-1607334-1-1.html</a>    
    
    
