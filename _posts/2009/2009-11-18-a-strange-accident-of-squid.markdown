---
layout: post
theme:
  name: twitter
title: squid一次诡异事故
date: 2009-11-18
category: squid
---

前几天出了一次诡异的事情。某客户在半夜2点钟更新了其网站的内容后，按照刷新规则，squid应该在15分钟内也更新成新内容的。但实际情况却是新网页一刷新没准就变成旧的，一直到5点左右这种现象才算是消失了。

用前段时间写的age测试脚本检查全部服务器，赫然发现有些服务器上的测试文件的age卡在102164686，也就是三年多！

经过整整一个下午的刷新观察，所有的服务器都陆续出现过这种情况，然后不定什么时间age又突然回复正常计数一段时间…等了很久，捕捉到一个现象，就是金华节点的测试age在896的时候，我一刷新，变成102164686了。也就可以认为，这个服务器的age计数在到达15分钟去源站比对文件的时候，突然变成102164686了。

因为之前脚本过滤了其他信息，只显示HTTP1/0|Age|Cache三行。于是改手动wget看全部信息。结果无意的刷新几遍后，赫然发现有一次header里的Date居然是2006年！难道是这台机器有问题？确认本机date无误后，我又登陆其他节点几台机器一一试验，都出现这个情况……于是在crontab里执行每5分钟从源站wget一次测试文件，过两天来看看结果，如下所示：
```bash
[root@squid1 ~]# cat /root/wget.log|awk '/Last/{print $0}' |sort -n |uniq -c
803   Last-Modified: Thu, 12 Nov 2009 05:58:12 GMT
1   Last-Modified: Thu, 24 Aug 2006 00:09:51 GMT
1   Last-Modified: Thu, 24 Aug 2006 00:24:52 GMT
1   Last-Modified: Thu, 24 Aug 2006 00:29:51 GMT
1   Last-Modified: Thu, 24 Aug 2006 00:44:51 GMT
1   Last-Modified: Thu, 24 Aug 2006 00:49:51 GMT
[root@squid1 ~]# cat /root/wget.log|awk '/Last/{print $5}' |sort -n |uniq -c
381 2006
803 2009
```
源站文件的Last-Modified时间居然在变化！而且除了正确的2009年时间不变外，2006年的时间居然是随着时间走的（crontab是5分钟，wget日志里每次Last-Modified的时间也是隔5分钟）……

由此基本确定是客户源站的问题，我的理解是：当cache服务器到时去源站比对时间时，如果碰上源站这会儿时间是2009年，就更新文件并重计age；如果碰上源站这会儿时间是2006年了，那cache比源站还新，自然没法变动了……

但让我不解的是：header信息里Date字段时间变化，还可以说是服务器系统时间不正常，文件的Last-Modified为什么会这样变化呢？！

