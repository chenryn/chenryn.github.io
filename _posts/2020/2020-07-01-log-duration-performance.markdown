---
layout: post
theme:
  name: twitter
title: 日志输出的耗时，大家关注过么？
category: logstash
---

在2013年，我还在人人网工作的时候，曾经做过一次Nginx性能压力测试，其中一项是access_log配置的影响，那是我第一次知道原来打日志这事儿在极限情况下对服务性能有这么大的影响。当时的原始记录见：[Nginx 万兆网络环境测试](/2013/02/25/nginx-testing-10Gibps/#section-10)

今天偶然看到一篇SREcon上的分享，来自彭博社，其中统计了几种不同方式的日志输出的时延分布情况，转来给大家一读：

![](https://pic4.zhimg.com/v2-a9e8549028714da5025f1a9c5ffab32b_r.jpg)

这是标准的写本地磁盘的情况。

![](https://pic2.zhimg.com/v2-7633294e7b6219b34b611c943ac0b285_r.jpg)

这是不落本地磁盘，直接发送给远端HTTP接收器的情况。

![](https://pic2.zhimg.com/v2-f5b99a7a31fb2768e752718bb08cb489_r.jpg)

这是限定同步写日志的情况。

可以看到，如果是同步写，或者远程写，时延都可以到ms级别，甚至接近s级别。可惜分享中没有给出更具体的测试背景资料，也没有本地unix socket的对比。

总之，还是那个结论，应用日志尽量带buffer打本地磁盘，或者unix socket给rsyslogd，让rsyslogd来处理落盘还是转发。
