---
layout: post
theme:
  name: twitter
title: squid加载tcmalloc性能优化测试(动态)
date: 2010-02-01
category: squid
tags:
  - squid
  - tcmalloc
---

昨天下午在一台squid上加载了tcmalloc。运行到现在，整整一天时间。现取LVS下与其完全相同配置的另一台未加载tcmalloc的squid服务器进行比较。
环境说明：
CPUinfo：Intel(R) Xeon(R) CPU  E5405  @ 2.00GHz
MEM：4G
SQUID：Version 2.6.STABLE21
当单台流量20M，TCP连接数6w时，未加载tcmalloc的服务器CPU占用率和负载情况如下图：
<img src="/images/uploads/62d80b5eh730dca4ebd76690.jpg" alt="" title="cpu%" width="572" height="263" class="alignnone size-full wp-image-2559" />
CPU占用率
<img src="/images/uploads/62d80b5eh730dca57d6ee690.jpg" alt="" title="loadavg" width="575" height="257" class="alignnone size-full wp-image-2561" />
负载
<hr>
而同时，加载了tcmalloc的服务器CPU占用率和负载情况如下图：
<img src="/images/uploads/62d80b5eh730dca5f8985690.jpg" alt="" title="cpu%-new" width="577" height="263" class="alignnone size-full wp-image-2562" />
CPU占用率
<img src="/images/uploads/62d80b5eh730dca671bb7690.jpg" alt="" title="loadavg-new" width="579" height="259" class="alignnone size-full wp-image-2563" />
负载（上一个尖峰就是我加载tcmalloc的时候）

从图中来看，加载tcmalloc，确实对squid处理高并发小图片请求有一定的性能优化帮助，但其本身对系统资源又有一定的耗用，导致负载反而略微提高（CPU占用率中sys也变高了）。而在并发量不大的时候，加载tcmalloc占用的CPU资源在图中也有显现。

或许这就是官方不建议采用动态加载方式的原因？下一步试验，采用重编译方式测试。

