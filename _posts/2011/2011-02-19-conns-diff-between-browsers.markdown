---
layout: post
theme:
  name: twitter
title: 浏览器连接数的小区别
date: 2011-02-19
category: CDN
---

读百度UEO博客的文章《<a href="http://www.baiduux.com/blog/2011/02/15/browser-loading/" target="_blank">浏览器的加载与页面性能优化</a>》，其中关于浏览器对单个域名连接数有一段描述，与一般的概述稍有差别。由此可见像百度这种级别的公司，对性能细节抓到什么程度——让我想起之前在腾讯大讲堂里看到的"页面代码大小要求是MTU倍数"。

这段文字如下：
在HTTP/1.1协议下，单个域名的最大连接数在IE6中是2个，而在其它浏览器中一般4-8个，而整体最大链接数在30左右

而在HTTP/1.0协议下，IE6、7单个域名的最大链接数可以达到4个，在Even Faster Web Sites一书中的11章还推荐了对静态文件服务使用HTTP/1.0协议来提高IE6、7浏览器的速度
