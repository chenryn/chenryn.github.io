---
layout: post
title: tmpfs的inode问题
date: 2011-06-09
category: linux
---

一些squid服务器为了强调加速效果，使用tmpfs来做cache_dir。刚开始运行的时候也嗖嗖的，不过没过一两天，mgr:info就看到缓存命中率急剧下降，字节命中率甚至只剩下10%左右！检查了多次配置，绝对没有问题，但同样的url，曾经一分钟几百次的HIT，现在一分钟几百次MISS……
df看，不管是tmpfs，还是logs所在的目录，都才用了不到30%。最后想起来df -i看了下，果然，tmpfs的inode使用率100%了！
赶紧remount了一次，解决了问题。但不是根本出路。还是得想办法搞定这个inode。
在linux代码说明里找到了关于tmpfs的文档（/usr/src/linux/Documentation/filesystems/tmpfs.txt）：
    tmpfs has three mount options for sizing:
    ……
    nr_inodes: The maximum number of inodes for this instance. <strong>The default
               is half of the number of your physical RAM pages</strong>, or (on a
               machine with highmem) the number of lowmem RAM pages,
               whichever is the lower.
    These parameters accept a suffix k, m or g for kilo, mega and giga and
    can be changed on remount.  The size parameter also accepts a suffix %
    to limit this tmpfs instance to that percentage of your physical RAM:
    <strong>the default, when neither size nor nr_blocks is specified, is size=50%</strong>
    
    If nr_blocks=0 (or size=0), blocks will not be limited in that instance;
    <strong>if nr_inodes=0, inodes will not be limited.</strong>  It is generally unwise to
    mount with such options, since it allows any user with write access to
    use up all the memory on the machine; but enhances the scalability of
    that instance in a system with many cpus making intensive use of it.
linux默认的RAM page大小是4k，好了来计算一下吧。
{% highlight bash %}[root@bbs_squid4 ~]# df -i|awk '/tmpfs/{print $2}'
504912
[root@bbs_squid4 ~]# free -k|awk '/Mem/{print $2/4/2}'
504912{% endhighlight %}
果然如此！
那么真正的解决办法也就有了：
{% highlight bash %}[root@localhost ~]# mount -t tmpfs -o size=2000M,mode=777,nr_inodes=0 tmpfs /tmpfs
[root@localhost ~]# df -i|grep tmpfs
tmpfs                      0       0       0    -  /tmpfs{% endhighlight %}
