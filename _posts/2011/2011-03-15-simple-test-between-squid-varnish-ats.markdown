---
layout: post
title: squid/varnish/ats简单测试
date: 2011-03-15
category: CDN
tags:
  - squid
  - varnish
  - ats
---

简单的试试varnish和apache traffic server。跟squid进行一下对比。
介于varnish和ats都是出现不太久的东西（至少是开源流行不长），选择其最新开发版本测试，正巧都是2.15版。呵呵~
varnish配置文件，只修改了backend到具体某台nginx发布点上。其他都是反向代理缓存的标配。（可参考张宴博客http://blog.s135.com和varnish权威指南http://linuxguest.blog.51cto.com/195664/354889）
ats说明更少，从目前的资料看，修改了records.config中的监听，cache.config遵循源站未改，remap.config添加了map一条，绑定域名到同一台nginx上。
注：varnish和ats都没有修改缓存路径，即分别为var/varnish/varnish.cache和var/trafficserver，都是磁盘。

然后从线上某台squid2.7上收集www.domain.com下的html页面url一共164条，存成urllist。
使用http_load进行测试。第一遍，先用http_load -r 100 -s 10完成cache的加载；第二遍改用-r 1000 -s 60进行测试。
1、先是varnish
开另一个窗口看netstat，发现在第一次加载的时候，varnish启动了相当多的链接到后端nginx请求数据！第二遍时，-r1000一直在刷wrong，修改成-r900就没有问题。最后的报告显示fetch/sec还略大于指定的900达到990，建连时间平均1.3ms，响应时间1.8ms。
2、然后ats
-r1000也报wrong，于是同样使用-r900，fetch/sec和和建连时间与varnish相近，响应时间2.1ms。
从trafficserver_shell的show:proxy_stats和show:cache_stats命令结果来看，缓存命中率98%，磁盘IO几乎没有。可见其实都在内存中返回了。
3、最后squid2.7.9
-r900时，fetch/sec只有880，响应时间1.9ms；提高到-r1000时，没有wrong报错，fetch/sec下降到850，响应时间2.3ms；另一个窗口的netstat命令直接卡住……
squid按照公司默认做法，缓存目录建在了tmpfs上。从squidclient来看，98%的命中率中只有三分之一是直接通过cache_mem返回的，另三分之二是通过cache_dir的tmpfs返回。

另：最后du -sh查看三者的缓存目录大小，赫然发现squid的是19M，ats是39M，varnish是41M。这个差别也是比较怪异的，值得后续研究……

从这个简单测试结果看，squid的稳定性依然没的说：对于大多数情况来说，是乐于见到这种宁愿响应慢点点也要保证响应正确的情况的；varnish在大批量回源时对后端服务器的冲击，显然比较让人担心；ats和varnish具有同样高效的响应速度（和高压下的错误……），而且其详细到甚至稍显繁琐的那堆config文件的配置格式，相比varnish来说，更加贴近运维人员（也就是说看起来不像编程语言）~~
