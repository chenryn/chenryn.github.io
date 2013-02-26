---
layout: post
title: 从天涯论坛看终极页的缓存控制
date: 2010-12-10
category: CDN
---

一般不太上天涯论坛灌水或者潜水，不过经常去天涯SA刘天斯的blog上逛逛~在他开源memlink后，想起来去天涯看看前端设计，发现其论坛主列表页采用nginx发布（预计有nginx的module直接读取memlink），终极页前端采用varnish缓存，回复时的动态asp页面由IIS处理。但在终极页上，虽然显示的server也还是IIS，我却有一定的怀疑~

在访问某终极页时，可以看到类似如下的header
Age:78
Cache-Control:public
Connection:close
Content-Encoding:gzip
Content-Length:34687
Content-Type:text/html
Date:Fri, 10 Dec 2010 09:03:48 GMT
Expires:Fri, 10 Dec 2010 09:07:30 GMT
Last-Modified:Fri, 10 Dec 2010 09:02:30 GMT
Server:Microsoft-IIS/6.0
Vary:Accept-Encoding
Via:Tianya Cache
X-Cache:HIT118
X-Powered-By:ASP.NET
X-tianya:1098678484 1098675384

如果按下F5，会看到一个IMS请求，最后返回304或者200的结果。

如果按下Ctrl+F5，会看到一个no-cache请求，最后返回200的结果。

不过奇怪的是，在no-cache请求后，虽然明知页面没有变（请求的是一个多页帖子的第一页，wget和wget --header 'Cache-Control: no-cache'下来后的页面的MD5值都一样），但返回的last-modified时间却变成了和Date一致的当前时间了。以至于让我怀疑这个*.shtml难道不是静态化生成的？

然后回复该帖。通过POST方式向另一个动态域名传输数据，并302跳转回原页面。由于POST方式的不可缓存性，浏览器自动带上了no-cache请求头，并传递给了302之后的动作，即以no-cache重新请求了原帖子的url，并重新下载了该页面。由此完成了对回复的即时更新——对于论坛来说，重要的就是发帖人自己能即时看到，其他人完全可以等一会页面过期或者IMS比对来看别人的新回复。

假设前面说到的shtml确实是静态化生成的话，那么这个直接跳转的做法就有一定的风险，即要求系统在极短时间（从浏览器时间看就是POST的firstbyte时间开始，到200的connection时间结束，网络较好的情况下应该是毫秒级）内，完成对终极页的静态化工作。
写到这里，愈发怀疑这个shtml是asp的伪装版了……
