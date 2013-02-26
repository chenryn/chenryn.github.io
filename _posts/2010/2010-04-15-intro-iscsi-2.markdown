---
layout: post
title: iscsi试验（成功 & 读写测试）
date: 2010-04-15
category: linux
---

隔了一天，回头再来mount /dev/sda /mnt；成功了~
不信邪，再上一台，login，mount，继续成功……
难道是前天rp不行？

然后试验写入。发现在每台client上的写入，都暂时不会显示在server和其他client上。只有经过logout和login后才会显示。
接着进行一下简单的读写速度测试，先是read，用hdparm工具，结果如下：

服务器端：[root@ct5 ~]# hdparm -tT /dev/xvdb1
/dev/xvdb1:
 Timing cached reads:   20880 MB in  1.99 seconds = 10486.02 MB/sec
 Timing buffered disk reads:  162 MB in  3.01 seconds =  53.85 MB/sec

客户端：[root@ct5 ~]# hdparm -tT /dev/sda
/dev/sda:
 Timing cached reads:   21944 MB in  1.99 seconds = 11022.51 MB/sec
 Timing buffered disk reads:  152 MB in  3.02 seconds =  50.41 MB/sec

然后用apache发布，wget的速度基本也差不多。

然后是write，用time dd，最开始指定了bs=4k，结果让我很惊讶

服务器端：[root@ct5 cache]# time dd if=/dev/zero of=rao bs=4k count=655360
655360+0 records in
655360+0 records out
2684354560 bytes (2.7 GB) copied, 35.1299 seconds, 76.4 MB/s    
real 0m35.204s    
user 0m0.440s    
sys 0m6.968s    

而客户端2684354560 bytes (2.7 GB) copied, 28.584 seconds, 93.9 MB/s    
real 0m28.650s    
user 0m0.496s    
sys 0m7.404s    

居然比服务器端还快。于是想到iscsi的封包机制，可能bs4k有影响，于是往下降成2k，结果立刻有体现了

服务器1342177280 bytes (1.3 GB) copied, 6.93954 seconds, 193 MB/s    
real 0m6.943s    
user 0m0.428s    
sys 0m4.848s    

客户端1342177280 bytes (1.3 GB) copied, 12.5357 seconds, 107 MB/s    
real 0m12.539s    
user 0m0.348s    
sys 0m4.720s    

再降成1k，结果稍慢

服务器671088640 bytes (671 MB) copied, 4.1199 seconds, 163 MB/s    
real 0m4.123s    
user 0m0.372s    
sys 0m3.280s    

客户端671088640 bytes (671 MB) copied, 7.06874 seconds, 94.9 MB/s    
real 0m7.093s    
user 0m0.328s    
sys 0m3.324s    
可见在写速率上，还是有一定差距的。
