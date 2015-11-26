---
layout: post
title: netperf网络测试
date: 2010-05-05
category: linux
---

本文的主要参考是IBM工作室的一篇文章：<a href="http://www.ibm.com/developerworks/cn/linux/l-netperf/index.html" target="_blank">http://www.ibm.com/developerworks/cn/linux/l-netperf/index.html</a>

文中指出网络性能的五个衡量指标，前两个是可用性和响应时间，这也是最经常关注的，因为有最常见的ping命令；然后是利用率、可用带宽和剩余带宽。

* 安装：
```bash
wget ftp://ftp.netperf.org/netperf/netperf-2.4.5.tar.gz
tar zxvf netperf-2.4.5.tar.gz -C /tmp
cd /tmp/netperf-2.4.5
./configure && make && make install
```
然后在服务器端运行/usr/local/bin/netserver启动服务，可以看到如下正确结果：

    Starting netserver at port 12865
    Starting netserver at hostname 0.0.0.0 port 12865 and family AF_UNSPEC

同样在客户端（即网络另一头的服务器上）安装好，就可以用/usr/local/bin/netperf工具进行测试了。

* 我的测试环境是：

S:121.14.225.197 汕头电信    
C:218.60.36.39 沈阳网通

绝对的跨网测试了，呵呵~

一、先测试默认的TCP_STREAM批量传输，结果如下：

    /usr/local/bin/netperf -H 121.14.225.197 -l 60
    TCP STREAM TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 121.14.225.197 (121.14.225.197) port 0 AF_INET
    Recv   Send    Send
    Socket Socket  Message  Elapsed
    Size   Size    Size     Time     Throughput
    bytes  bytes   bytes    secs.    10^6bits/sec
    873800 163840 163840    60.46       6.52

即电信设备采用873800字节的socket接收缓存，网通设备采用163840字节的socket发送缓存，测试60.46秒后，网络吞吐量为6.52Mb/s。

逐次采用-m修改发送包的大小后，发现在如下情况时，网络吞吐量是最好的（是默认发送分组的两倍半）：

    /usr/local/bin/netperf -H 121.14.225.197 -l 60 -- -m 8192
    TCP STREAM TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 121.14.225.197 (121.14.225.197) port 0 AF_INET
    Recv   Send    Send
    Socket Socket  Message  Elapsed
    Size   Size    Size     Time     Throughput
    bytes  bytes   bytes    secs.    10^6bits/sec
    873800 163840   8192    61.46      17.60

可见在南北互联中间某环节的路由器，限定了socket缓冲区的大小。

二、然后测试UDP的批量：

    /usr/local/bin/netperf -t UDP_STREAM -H 121.14.225.197 -l 60 -- -m 8192
    UDP UNIDIRECTIONAL SEND TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 121.14.225.197 (121.14.225.197) port 0 AF_INET
    Socket  Message  Elapsed      Messages
    Size    Size     Time         Okay Errors   Throughput
    bytes   bytes    secs            #      #   10^6bits/sec
    6553600    8192   60.01     6973545      0    7615.92
    6553600           60.01      393669            429.93

可以看到，只有5.65%的UDP分组被接收了……

三、小请求大应答模式的测试

1、数据库请求（一次TCP连接，反复传输数据）：

    /usr/local/bin/netperf -t TCP_RR -H 121.14.225.197  -- -r 32,1024
    TCP REQUEST/RESPONSE TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 121.14.225.197 (121.14.225.197) port 0 AF_INET
    Local /Remote
    Socket Size   Request  Resp.   Elapsed  Trans.
    Send   Recv   Size     Size    Time     Rate
    bytes  Bytes  bytes    bytes   secs.    per sec
    163840 873800 32       1024    10.00      18.49
    163840 873800

在32字节请求和1024字节响应的情况下，平均交易率为18.49次/秒。

2、HTTP请求（每次传输都新建连接）：

    /usr/local/bin/netperf -t TCP_CRR -H 121.14.225.197  -- -r 32,1024
    TCP Connect/Request/Response TEST from 0.0.0.0 (0.0.0.0) port 0 AF_INET to 121.14.225.197 (121.14.225.197) port 0 AF_INET
    Local /Remote
    Socket Size   Request  Resp.   Elapsed  Trans.
    Send   Recv   Size     Size    Time     Rate
    bytes  Bytes  bytes    bytes   secs.    per sec
    163840 873800 32       1024    10.00       9.30
    163840 873800

RPS几乎下降一般，可见TCP建连是很耗时间的。

3、还可以测试UDP_RR，理论上来说，去除掉TCP建连的耗时，UDP_RR的RPS应该有所提高。不过在我的跨网环境下，rps几乎低到0.1，考虑到之前测试得到的5%的收发率，这个测试基本只能在局域网内才有意义。

