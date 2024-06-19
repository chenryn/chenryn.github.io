---
layout: post
theme:
  name: twitter
title: header_replace试验
date: 2010-01-31
category: squid
---

在linuxtone论坛上，偶见一贴，说采用如下配置，browser就可以正常遵守originserver的过期设置，而且充分利用browser本身的缓存设置，对server来说就可以达到减少304请求的效果，从而提升机器性能，节省带宽云云……

header_access Age deny all
header_replace Age 1

这样reqly_header就显示成：Cache-Control: max-age=1。
（让我很郁闷的一点是squid.conf.default里提供的header_access配置条目不全……）

从之前的cache驻留时间系列里知道，在HTTP的header里，max-age的优先级别高于Expires[Cache-Control>Expires>refresh_pattern>Etag>Last-Modified]。如果这里把max-age改了，那哪里还有地方去控制过期呢？

我想，帖子里估计是写错了，试验一下，果然，其实修改后的header应该是：Age: 1。

这种情况，应该是为了防止Cache-Control: max-age=0的定义导致304的出现（网上看到过一个试验结果，squid最多最多能接受的刷新极限是64秒，我汗，这都有人测试~~）

既然Age永远到不了max-age的限定，自然max-age定义失效了；

接下来试验，refresh_pattern里的max和LM-fator算法是否起作用。结果让我很无语——
配置如右：refresh_pattern .gif$ 2 5% 5 ignore-reload

Date: Sun, 31 Jan 2010 10:32:45 GMT
Last-Modified: Mon, 17 Nov 2008 06:53:22 GMT

LM-fator过期时间应该是(10:32-6:53)*5%=11分钟。max为5分钟。
直到18:50:41还是HIT，Age=1，过期设定失效！

于是我取消http_replace和refresh配置生效后，18:53:15再wget，结果依然HIT，Age=155！

可见，之前LM-fator算法中的说法不完整，squid并不是单按照Date和Last-Modified时间就强制过期，它还得根据Age去判定——这点帖子倒是说对了，完全交给源站控制——问题在于，源站的运维如果真能策划好了这个，又何必让CDN在前端折腾这个age呢？鸡肋呀~~
<hr />
UPDATE：
今天有几个客户切去快网，我在测试时发现，Age就是都被改成了1。除了源站的定义以外，或者快网自认为其提供的刷新API功能很好很强大？？


