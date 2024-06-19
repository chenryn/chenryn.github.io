---
layout: post
theme:
  name: twitter
title: squid运行分析
date: 2010-02-06
category: squid
---

上回编译加载tcmalloc后，效果各有不同，所以还得细分具体运行情况，以便之后继续优化。
之前的架构是1个lvs下挂6台leaf+1台parent。现在已经给7台squid都加载tcmalloc了。leaf运行上佳，CPU占用率甚至降到了2%，loadavg也不过0.2。但parent的CPU占用率虽然降低，loadavg却依然在1以上——这对于单核服务器来说，可不是什么好事。分析日志，或者用squidclient分析cache情况，leaf如下：
cat access.log |awk '{if(/NONE/){a[NONE]++}}END{print a[NONE]/NR}'
0.981347
squidclient -p 80 mgr:info
    Cache information for squid:
    Request Hit Ratios: 5min: 97.8%, 60min: 98.3%
    Byte Hit Ratios: 5min: 97.8%, 60min: 98.2%
    Request Memory Hit Ratios: 5min: 85.8%, 60min: 86.8%
    Request Disk Hit Ratios: 5min: 9.8%, 60min: 9.1%
    Storage Swap size: 19891740 KB
    Storage Mem size: 1048572 KB
    Mean Object Size: 9.67 KB
可以看到缓存文件的平均大小不足10KB，绝大多数的请求都在内存中处理掉了。所以在加载了优化内存反应速度的tcmalloc后，效果那么明显。
parent如下：
$ cat access.log |awk '{if(/NONE/){a[NONE]++}}END{print a[NONE]/NR}'
0.179209
$ squidclient -p 80 mgr:info
    Cache information for squid:
    Request Hit Ratios: 5min: 31.1%, 60min: 32.3%
    Byte Hit Ratios: 5min: 38.4%, 60min: 36.9%
    Request Memory Hit Ratios: 5min: 7.8%, 60min: 12.2%
    Request Disk Hit Ratios: 5min: 32.7%, 60min: 37.9%
    Storage Swap size: 40300232 KB
    Storage Mem size: 524284 KB
    Mean Object Size: 11.68 KB
只有30%的缓存命中，而且基本还都是从磁盘读取的（awk结果排除了REFRESH_HIT，所以更低）。难怪上次优化没什么效用了……
为了保证服务，先给这组服务器加上了round-robin的双parent。新parent的硬件情况和老的一样。而squid配置上，则采用了aufs方式，不再使用diskd方式。运行到现在30个小时，分析如下：
$ cat /cache/logs/access.log |awk '{if(/NONE/){a[NONE]++}}END{print a[NONE]/NR}'
0.238754
$ squidclient -p 80 mgr:info
    Cache information for squid:
    Request Hit Ratios: 5min: 22.7%, 60min: 22.8%
    Byte Hit Ratios: 5min: 22.9%, 60min: 20.1%
    Request Memory Hit Ratios: 5min: 22.2%, 60min: 24.3%
    Request Disk Hit Ratios: 5min: 64.4%, 60min: 65.0%
    Storage Swap size: 4640308 KB
    Storage Mem size: 1048588 KB
    Mean Object Size: 9.08 KB

看起来差不多的样子。
因为确认mem没怎么用上，下一步看disk的I/O。
采用diskd的parent如下：

    [root@tinysquid2 ~]# iostat -x /dev/xvdb2 5 5
    Linux 2.6.18-128.el5xen (tinysquid2)
    02/06/2010
    avg-cpu: %user   %nice %system %iowait %steal   %idle
    0.00 0.00 0.00 10.00 0.00   90.00
    Device: rrqm/s wrqm/s r/s w/s rsec/s   wsec/s avgrq-sz avgqu-sz await  svctm  %util
    xvdb2
    0.00 5.00  8.60 46.60 81.60 412.80 8.96 0.32 5.80 1.75   9.68

采用aufs的parent如下：

    [root@tinysquid3 ~]# iostat -x /dev/xvdb2 5 5
    Linux 2.6.18-128.el5xen (tinysquid3)
    02/06/2010
    avg-cpu: %user   %nice %system %iowait %steal   %idle
    0.20 0.00 0.40 1.60 0.20   97.60
    Device: rrqm/s wrqm/s r/s w/s rsec/s   wsec/s avgrq-sz avgqu-sz await  svctm  %util
    xvdb2
    0.00 8.58  3.19 6.19 25.55 118.16 15.32 0.02 2.47 1.70   1.60

以上结果的解释如下：

rrqm/s: 每秒进行 merge 的读操作数目。即 delta(rmerge)/s    
wrqm/s: 每秒进行 merge 的写操作数目。即 delta(wmerge)/s    
r/s: 每秒完成的读 I/O 设备次数。即 delta(rio)/s    
w/s: 每秒完成的写 I/O 设备次数。即 delta(wio)/s    
rsec/s: 每秒读扇区数。即 delta(rsect)/s    
wsec/s: 每秒写扇区数。即 delta(wsect)/s    
rkB/s: 每秒读K字节数。是 rsect/s 的一半，因为每扇区大小为512字节。(需要计算)    
wkB/s: 每秒写K字节数。是 wsect/s 的一半。(需要计算)    
avgrq-sz: 平均每次设备I/O操作的数据大小(扇区)。delta(rsect+wsect)/delta(rio+wio)    
avgqu-sz: 平均I/O队列长度。即 delta(aveq)/s/1000(因为aveq的单位为毫秒)。    
await: 平均每次设备I/O操作的等待时间 (毫秒)。即delta(ruse+wuse)/delta(rio+wio)    
svctm: 平均每次设备I/O操作的服务时间 (毫秒)。即 delta(use)/delta(rio+wio)    
%util: 一秒中有百分之多少的时间用于 I/O 操作，或者说一秒中有多少时间 I/O 队列是非空的。即 delta(use)/s/1000(因为use的单位为毫秒)    

从上面的运行情况看，都是w操作为主，但diskd比aufs每秒w的次数要大，而每次w的服务时间也大——大的同时波动性也不太稳定——由此导致rw时的等待时间也延长——进一步的结果就是I/O非空时间变少——最后的结果就是disk的I/O压力变大！
因为现在已经双parent，loadavg降低，所以不好看出之前的高loadavg问题关键。不过至少从现在的运行来看，aufs比diskd要好。

————————————————————————————————————————
3月25日补充：

aufs虽然是异步io，但某些文件默认的写操作并不如此。需要在编译时修改src/fs/aufs/store_asyncufs.h中的#define ASYNC_WRIT值为1。
对于aufs，可以使用squidclient mgr:squidaio_counts查看，其中queue一项，据说不应该超过线程数量的5倍。而线程数量跟cache_dir数量的关系如下：

cache_dirs Threads
1               16
2               26
3               32
4               36
5               40
6               44

