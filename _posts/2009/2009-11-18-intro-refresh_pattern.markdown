---
layout: post
title: cache驻留时间（一、refresh_pattern）
date: 2009-11-18
category: CDN
tags:
  - cache
---

上一篇举了个缓存时间的事故，现在说说普通情况下影响这个的配置：

首先，refresh_pattern规则仅仅应用到没有明确过时期限的响应。原始服务器能使用Expires头部，或者Cache-Control:max-age指令来指定过时期限。

然后，介绍一下LM-factor算法：

LM-factor=(response age)/(resource age)

    响应年龄（即response age）=当前时间-对象进入cache的时间
    源年龄（即resource age）=对象进入cache的时间-对象的last_modified

就好比上篇，因为Last-Modified错误，源年龄变成了三年，而响应年龄相对三年来说太短了，所以LM-factor也就很小很小，永远达不到警戒线……

最后常用刷新选项：

** ignore-reload
该选项导致squid忽略请求里的任何no-cache指令。如果希望内容一进入cache就不删除，直到被主动purge掉为止，可以加上ignore-reload选项,这个我们常用在mp3,wma,wmv,gif之类。

** override-expire
该选项导致squid在检查Expires头部之前，先检查min值。这样，一个非零的min时间让squid返回一个未确认的cache命中，即使该响应准备过期。

** override-lastmod
该选项导致squid在检查LM-factor百分比之前先检查min值。

** reload-into-ims
该选项导致squid以no-cache指令传送确认请求。换句话说，squid在转发请求之前，对该请求增加一个If-Modified-Since头部。注意这点仅仅在目标有Last-Modified时间戳时才能工作。外面进来的请求保留no-cache指令，以便它到达原始服务器。
一般情况可以使用reload-into-ims。它其实是强行控制对象的超时时间，这违反了http协议的精神，但是在带宽较窄的场合，可以提高明显系统相应时间。
以上这段是网上百度的，其实最后一段是废话，squid缓存选项，各个都是有违http协议精神的……


