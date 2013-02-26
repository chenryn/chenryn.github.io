---
layout: post
title: lvs的activeconn与netstat的conn
date: 2010-04-02
category: linux
---

曾经有过一组高并发请求的服务器，在lvs上看到单台activeconn=~220000；同时，在RS上执行netstat -s -t|grep "connections established"结果=~65000，而squidclient mgr:5min|grep client_http.requests结果=~180。后来说起并发数的时候，有些茫然，到底哪个才算是呢？

今天在squid-user里问起，居然有幸碰见另一位中国订阅者，夏兄随后提供给我一个06年的帖子，所述甚详。算是解惑了~
<a href="http://www.linuxsir.org/bbs/showthread.php?t=248500"><u><font color="#0000ff">http://www.linuxsir.org/bbs/showthread.php?t=248500</font></u></a>
原来lvs默认有个超时时间，可以用ipvsadm -L --timeout查看，默认是900 120 300，分别是TCP TCPFIN UDP的时间。
而RS上参数如下：
{% highlight bash %}
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
{% endhighlight %}
可见RS的超时时间（仅指ESTABLISHED）比LVS小了3倍。再加上WAIT和SYN_RECV等状态，差不多就是220000/65000的比例了。而squid的RPS是按秒计算的，180*300=~55000，在数量级上和netstat的结果也就差不多了~ 
