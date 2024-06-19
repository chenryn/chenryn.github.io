---
layout: post
theme:
  name: twitter
title: netfilter的conntrack优化
date: 2010-02-06
category: linux
tags:
  - iptables
---

[参考原文](http://www.wallfire.org/misc/netfilter_conntrack_perf.txt)
[中文版](http://www.linuxmine.com/5791.html)
说是zz，好歹也是自己看完以后的zz，所以组织语言次序都是自己来：
首先解释两个概念性的名词

conntrack最大数量.叫做conntrack_max
存储这些conntrack的hash表的大小,叫做hashsize
hash表存在于固定的的不可swap的内存中.
conntrack_mark决定占用多少这些不可swap的内存
hashsize=conntrack_max/8=ramsize(in bytes)/131072/(x/32)
x表示使用的指针类型是(32位还是64的)

读取conntrack_max值
cat /proc/sys/net/ipv4/ip_conntrack_max

读取hashsize值
cat /proc/sys/net/ipv4/netfilter/ip_conntrack_buckets

ip_conntrack buffer使用情况
grep conn /proc/slabinfo

文章提出的sysctl参数修改：
```bash
#允许TCP/UDP打开的本地端口范围
echo "1024 65000" > /proc/sys/net/ipv4/ip_local_port_range
#内存脏数据回收参数，2.6内核中没有……
echo "100 1200 128 512 15 5000 500 1884 2">/proc/sys/vm/bdflush
#禁止ICMP ECHO响应
echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
#记录伪装广播帧响应日志
echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
#允许转发
echo "1" > /proc/sys/net/ipv4/ip_forward
#可用的共享内存总量(bytes)
echo "268435456" >/proc/sys/kernel/shmall
#内核允许的最大共享内存段大小(bytes)
echo "536870912" >/proc/sys/kernel/shmmax
#链接跟踪库允许的最大值
echo "1048576" > /proc/sys/net/ipv4/netfilter/ip_conntrack_max
#TCP链接established状态的超时时间，同理，还有wait/close/last_ack等的超时时间设定
echo "600" > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_timeout_established
#决定检查一次相邻层记录的有效性的周期
echo "240" > /proc/sys/net/ipv4/neigh/default/gc_stale_time
#存在于ARP高速缓存中的最少层数，如果少于这个数，垃圾收集器将不会运行
echo "1024" > /proc/sys/net/ipv4/neigh/default/gc_thresh1
#保存在 ARP 高速缓存中的最多的记录软限制。垃圾收集器在开始收集前，允许记录数超过这个数字 5 秒
echo "2048" > /proc/sys/net/ipv4/neigh/default/gc_thresh2
#保存在 ARP 高速缓存中的最多记录的硬限制，一旦高速缓存中的数目高于此，垃圾收集器将马上运行
echo "4096" > /proc/sys/net/ipv4/neigh/default/gc_thresh3
#路由缓存最大值
echo "52428800" > /proc/sys/net/ipv4/route/max_size
#允许中继网络中的arp包
echo "1" > /proc/sys/net/ipv4/conf/all/proxy_arp
#TCP/IP会话的滑动窗口大小可变
echo "1" > /proc/sys/net/ipv4/tcp_window_scaling
```
最直接看到的两个调整，就是ip_conntrack_max和ip_conntrack_tcp_timeout_established了。
而gc_*四个参数，是修改内核维护ARP表的参数，当arp -an|wc -l大于300的话，就需要修改这些参数，不然会出现“neighbour table overflow”或者“kernel: printk: 24 messages suppressed”这样的syslog，导致服务器ssh、ping无响应！


