---
layout: post
theme:
  name: twitter
title: url_rewrite配置的小区别
date: 2010-05-20
category: squid
---

一直以为squid的url_rewrite就是改写url后，传给squid分析是否缓存，然后返回缓存或者回源。在浏览器地址栏上的url是不变的。
今天才知道在print $uri的时候，可以给他加上http_code。变成print 302:$uri的格式，然后就可以由浏览器发起302跳转到新页面了。
