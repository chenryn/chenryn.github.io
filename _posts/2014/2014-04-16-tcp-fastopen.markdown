---
layout: post
title: TCP Fast Open 测试(1)
category: linux
tags:
  - nginx
  - systemtap
---

首先，这是一个未完成的测试。

新闻上大家都知道，Nginx从1.5.8开始支持fastopen参数，Linux从3.5开始支持fastopen特性，并在3.10开始默认开启。

httping是一个模拟ping输出的http请求客户端。从1.5开始支持发送fastopen请求，目前版本是2.3.4。

我在 fedora 20 (内核3.13版) 上编译了 nginx 1.5.13，yum 安装了 httping 2.3.3版。

开两个终端，一个运行tcpdump，然后另一个运行httping如下：

    httping -F -g http://www.google.com.hk/url -c 1

这时候看到前一个终端的输出是这样的：

>    [chenlin.rao@com21-100 tfo]$ sudo tcpdump -i p5p1 -vvnxXs 0 tcp port 80
>    tcpdump: listening on p5p1, link-type EN10MB (Ethernet), capture size 65535 bytes
>    20:40:15.034486 IP (tos 0x0, ttl 64, id 52862, offset 0, flags [DF], proto TCP (6), length 147)
>        10.2.5.100.40699 > 74.125.128.199.http: Flags [S], cksum 0xbb34 (correct), seq 3616187260:3616187335, win 29200, options [mss 1460,sackOK,TS val 31091970 ecr 0,nop,wscale 7,exp-tfo cookie 9a8e5a15f1deab96], length 75
>    	0x0000:  4500 0093 ce7e 4000 4006 913c 0a02 0564  E....~@.@..<...d
>    	0x0010:  4a7d 80c7 9efb 0050 d78a a37c 0000 0000  J}.....P...|....
>    	0x0020:  d002 7210 bb34 0000 0204 05b4 0402 080a  ..r..4..........
>    	0x0030:  01da 6d02 0000 0000 0103 0307 fe0c f989  ..m.............
>    	0x0040:  9a8e 5a15 f1de ab96 4845 4144 202f 7572  ..Z.....HEAD./ur
>    	0x0050:  6c20 4854 5450 2f31 2e30 0d0a 486f 7374  l.HTTP/1.0..Host
>    	0x0060:  3a20 7777 772e 676f 6f67 6c65 2e63 6f6d  :.www.google.com
>    	0x0070:  2e68 6b0d 0a55 7365 722d 4167 656e 743a  .hk..User-Agent:
>    	0x0080:  2048 5454 5069 6e67 2076 322e 332e 330d  .HTTPing.v2.3.3.
>    	0x0090:  0a0d 0a                                  ...
>    20:40:15.295644 IP (tos 0x0, ttl 30, id 42640, offset 0, flags [none], proto TCP (6), length 52)
>        74.125.128.199.http > 10.2.5.100.40699: Flags [S.], cksum 0x71c1 (correct), seq 1878126810, ack 3616187261, win 42900, options [mss 1430,nop,nop,sackOK,nop,wscale 6], length 0
>    	0x0000:  4500 0034 a690 0000 1e06 1b8a 4a7d 80c7  E..4........J}..
>    	0x0010:  0a02 0564 0050 9efb 6ff1 f0da d78a a37d  ...d.P..o......}
>    	0x0020:  8012 a794 71c1 0000 0204 0596 0101 0402  ....q...........
>    	0x0030:  0103 0306                                ....
>    20:40:15.295694 IP (tos 0x0, ttl 64, id 52863, offset 0, flags [DF], proto TCP (6), length 115)
>        10.2.5.100.40699 > 74.125.128.199.http: Flags [P.], cksum 0x5bf7 (correct), seq 1:76, ack 1, win 229, length 75
>    	0x0000:  4500 0073 ce7f 4000 4006 915b 0a02 0564  E..s..@.@..[...d
>    	0x0010:  4a7d 80c7 9efb 0050 d78a a37d 6ff1 f0db  J}.....P...}o...
>    	0x0020:  5018 00e5 5bf7 0000 4845 4144 202f 7572  P...[...HEAD./ur
>    	0x0030:  6c20 4854 5450 2f31 2e30 0d0a 486f 7374  l.HTTP/1.0..Host
>    	0x0040:  3a20 7777 772e 676f 6f67 6c65 2e63 6f6d  :.www.google.com
>    	0x0050:  2e68 6b0d 0a55 7365 722d 4167 656e 743a  .hk..User-Agent:
>    	0x0060:  2048 5454 5069 6e67 2076 322e 332e 330d  .HTTPing.v2.3.3.
>    	0x0070:  0a0d 0a                                  ...
>    20:40:15.560807 IP (tos 0x0, ttl 30, id 42641, offset 0, flags [none], proto TCP (6), length 40)
>        74.125.128.199.http > 10.2.5.100.40699: Flags [.], cksum 0x5720 (correct), seq 1, ack 76, win 670, length 0
>    	0x0000:  4500 0028 a691 0000 1e06 1b95 4a7d 80c7  E..(........J}..
>    	0x0010:  0a02 0564 0050 9efb 6ff1 f0db d78a a3c8  ...d.P..o.......
>    	0x0020:  5010 029e 5720 0000 0000 0000 0000       P...W.........
>    20:40:15.568068 IP (tos 0x0, ttl 30, id 42642, offset 0, flags [none], proto TCP (6), length 269)
>        74.125.128.199.http > 10.2.5.100.40699: Flags [P.], cksum 0x85ae (correct), seq 1:230, ack 76, win 670, length 229
>    	0x0000:  4500 010d a692 0000 1e06 1aaf 4a7d 80c7  E...........J}..
>    	0x0010:  0a02 0564 0050 9efb 6ff1 f0db d78a a3c8  ...d.P..o.......
>    	0x0020:  5018 029e 85ae 0000 4854 5450 2f31 2e30  P.......HTTP/1.0
>    	0x0030:  2034 3034 204e 6f74 2046 6f75 6e64 0d0a  .404.Not.Found..
>    	0x0040:  436f 6e74 656e 742d 5479 7065 3a20 7465  Content-Type:.te
>    	0x0050:  7874 2f68 746d 6c3b 2063 6861 7273 6574  xt/html;.charset
>    	0x0060:  3d55 5446 2d38 0d0a 4461 7465 3a20 5765  =UTF-8..Date:.We
>    	0x0070:  642c 2031 3620 4170 7220 3230 3134 2031  d,.16.Apr.2014.1
>    	0x0080:  323a 3430 3a31 3520 474d 540d 0a53 6572  2:40:15.GMT..Ser
>    	0x0090:  7665 723a 2067 7773 0d0a 436f 6e74 656e  ver:.gws..Conten
>    	0x00a0:  742d 4c65 6e67 7468 3a20 3134 3238 0d0a  t-Length:.1428..
>    	0x00b0:  582d 5853 532d 5072 6f74 6563 7469 6f6e  X-XSS-Protection
>    	0x00c0:  3a20 313b 206d 6f64 653d 626c 6f63 6b0d  :.1;.mode=block.
>    	0x00d0:  0a58 2d46 7261 6d65 2d4f 7074 696f 6e73  .X-Frame-Options
>    	0x00e0:  3a20 5341 4d45 4f52 4947 494e 0d0a 416c  :.SAMEORIGIN..Al
>    	0x00f0:  7465 726e 6174 652d 5072 6f74 6f63 6f6c  ternate-Protocol
>    	0x0100:  3a20 3830 3a71 7569 630d 0a0d 0a         :.80:quic....

没错，在第一个 SYN 包的时候就把 HEAD 请求带过去了。

但是发现比较奇怪的是很多时候一模一样的命令，SYN 包上就没带数据。

按我的想法，既然还是第一个 SYN 包，客户端这边压根不知道服务器端的情况，那么应该不管服务器端如何 SYN 里都带有 HEAD 请求啊？

--------------------------------------------------------

另外，用 `httping -F` 命令测试自己编译的 nginx 的时候，一直都没看到正确的抓包结果，HEAD 请求一直都是在三次握手后发送的。

试图用 systemtap 来追踪一些问题。

第一步确认我的 nginx 的 socket 是不是真的开了 fastopen：

一个终端运行如下命令：

    stap -e 'probe kernel.function("do_tcp_setsockopt") {printf("%d\n", $optname)}'

另一个终端启动nginx，看到前一个终端输出结果为`23`，查 `tcp.h` 可以看到 23 正是 `TCP_FASTOPEN` 没错！

第二步确认 httping 发送的时候是不是开了 fastopen：

一个终端运行如下命令：

    stap -e 'probe kernel.function("tcp_sendmsg") {printf("%d %x\n",$msg->msg_namelen,$msg->msg_flags)}'

另一个终端运行最开始提到的 `httping -F` 命令，看到前一个终端输出结果为 `16 20000040`，查 `tcp.h` 可以看到 `MSG_FASTOPEN` 是 `0x20000000`，`MSG_DONTWAIT` 是 `0x40`，也就是说 httping 也没问题。

现在比较郁闷的一点是：在 `net/ipv4/tcp.c` 里，`tcp_sendmsg()` 函数会判断 `if ((flags & MSG_FASTOPEN))`，就调用 `tcp_sendmsg_fastopen()` 函数来处理。但是试图用 systemtap 来调查这个函数的时候，会报一个错：

    WARNING: probe kernel.function("tcp_sendmsg_fastopen@net/ipv4/tcp.c:1005") (address 0xffffffff815cca08) registration error (rc -22)

原因还未知。

留记，继续研究。

--------------------------------------------------------

注1：发现 chrome 即使在 `about:flags` 里启用了 fastopen 好像也不行，必须命令行 `google-chrome --enable-tcp-fastopen` 这样打开才行。

注2：网上看到有人写server和client的demo演示fastopen，但其实不对，demo代码里print的数据是正常三次握手以后socket收到的。这点开tcpdump才能确认到底是什么时候发送的数据。

