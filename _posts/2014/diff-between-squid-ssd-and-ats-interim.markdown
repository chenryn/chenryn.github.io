---
layout: post
title: squid-ssd方案和trafficserver的interim层的异同
category: cache
tags:
  - trafficserver
  - squid
  - linux
---

最近重新捡起来两年前做的 cache 软件测试对比，把原先的 trafficserver 淘宝分支升级到了现在的社区主分支，主要区别就是配置文件里不再直接叫 `ssd.storage`，而是正规化的起了一个名字叫`interim cache layer`。

运行结果和当初类似，SATA 盘的 ioutil% 依然是远高于鄙司自创的 squid-ssd 方案。

于是沉下心来思考了一下为什么会有这么大的差距。

首先，squid-ssd 的设计其实非常简单，参照 Facebook 的 flashcache 原理扩展了 squid 原有的 COSS 存储引擎而已。所以我们先回忆一下 flashcache 的原理：

flashcache 是利用了 Linux 的 device-mapper 机制来虚拟逻辑块设备，在 ssd 和 sata 设备之间，flashcache 设计了三种模式：

1. Writethrough 模式，__数据同时写到 ssd 和 sata 硬盘__，官方文档的说明是：

> safest, all writes are cached to ssd but also written to disk
> immediately. If your ssd has slower write performance than your disk (likely
> for early generation SSDs purchased in 2008-2010), this may limit your system
> write performance. All disk reads are cached (tunable).

2. Writearound 模式，__数据绕过 ssd，直接写到 sata 设备上__，官方文档的说明是：

> again, very safe, writes are not written to ssd but directly to
> disk. Disk blocks will only be cached after they are read. All disk reads
> are cached (tunable).

3. Writeback 模式，__数据一开始只写到 ssd 上，然后根据缓存策略再移到 sata 设备上__，官方文档的说明是：

> fastest but less safe. Writes only go to the ssd initially, and
> based on various policies are written to disk later. All disk reads are
> cached (tunable).

squid-ssd 方案，学习的是 Writeback 模式，这种模式极大的缓解了普通 sata 设备的读写压力，牺牲了一定的数据安全。但是作为 CDN 缓存软件，本身就不需要保证这点 —— 这应该是源站来保证的。

相反，阅读了 ats 的文档说明后，发现 ats 的 interim 方案学习的是 Writearound 模式，而且默认的 tunable 那点还设的比较高， sata 设备上一个缓存对象要累积 2 次读取请求(最低可以修改到1，不能到0)后，才会缓存到 ssd 设备里去。

这一点从另一个细节上也可以反映出来：ats 的监控数据中，`Total Cache Size` 是只计算了 `storage.config` 里写的那些 sata 设备容量的，不包括 interim 在的 ssd 设备容量。
