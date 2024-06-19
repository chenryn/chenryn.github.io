---
layout: post
theme:
  name: twitter
title: lvs的activeconn与netstat的conn
date: 2010-04-02
category: linux
---

曾经有过一组高并发请求的服务器，在lvs上看到单台 activeconn 约等于 220000；同时，在RS上执行 `netstat -s -t|grep "connections established"` 结果大概是 65000，而 `squidclient mgr:5min|grep client_http.requests` 结果却只有 180。后来说起并发数的时候，有些茫然，到底哪个才算是呢？

今天在squid-user里问起，居然有幸碰见另一位中国订阅者，夏兄随后提供给我一个06年的帖子，所述甚详。算是解惑了~
<http://www.linuxsir.org/bbs/showthread.php?t=248500>

原来 lvs 默认有个超时时间，可以用 `ipvsadm -L --timeout` 查看，默认是 `900 120 300` ，分别是 `TCP TCPFIN UDP` 的时间。

而RS上参数如下：

```bash
net.ipv4.tcp_keepalive_time = 600
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_fin_timeout = 30
net.ipv4.netfilter.ip_conntrack_tcp_timeout_close = 10
net.ipv4.netfilter.ip_conntrack_tcp_timeout_max_retrans = 300
net.ipv4.netfilter.ip_conntrack_tcp_timeout_time_wait = 120
net.ipv4.netfilter.ip_conntrack_tcp_timeout_last_ack = 30
net.ipv4.netfilter.ip_conntrack_tcp_timeout_close_wait = 60
net.ipv4.netfilter.ip_conntrack_tcp_timeout_fin_wait = 120
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established = 300
net.ipv4.netfilter.ip_conntrack_tcp_timeout_syn_recv = 60
net.ipv4.netfilter.ip_conntrack_tcp_timeout_syn_sent = 120
net.ipv4.netfilter.ip_conntrack_udp_timeout_stream = 180
net.ipv4.netfilter.ip_conntrack_udp_timeout = 30
```

可见 RS 的超时时间（仅指 `ESTABLISHED` ）比 LVS 小了 3 倍。再加上 `WAIT` 和 `SYN_RECV` 等状态，差不多就是 220000/65000 的比例了。而 squid 的 RPS 是按秒计算的，`180*300=~55000` ，在数量级上和 netstat 的结果也就差不多了~ 
