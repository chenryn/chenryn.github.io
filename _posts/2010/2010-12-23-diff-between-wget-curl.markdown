---
layout: post
theme:
  name: twitter
title: wget和curl测试时的小区别
date: 2010-12-23
category: linux
---

在对网站内容是否更新进行测试时，最常用的两个工具就是wget和curl。不过两个工具之间还是有一些小区别，甚至很可能影响到测试结论的。记录一下：

1、在查看response-header的时候，我们习惯用的是wget -S和curl -I，但是：wget -S的时候，发送的是GET请求，而curl -I发送的是HEAD请求。如果测试url此时没有被缓存过，直接使用curl -I进行测试，永远都会返回MISS状态。所以最好先wget一次，再用curl -I。

2、在查看下载速度时，常常发现wget和curl耗时差距较大。因为wget默认使用HTTP/1.0协议，不显式指定--header="Accept-Encoding: gzip,deflate"的情况下，传输的是未经压缩的文件。而curl使用HTTP/1.1协议，默认接受就是压缩格式。

3、在测试缓存层配置时，有时发现wget可以HIT的东西，curl却始终MISS。对此可以开启debug模式进行观察跟踪。
wget自带有-d参数，直接显示request-header；curl只有-D参数，在采用GET请求的时候，将response-header另存成文件，所以只好在squid上debug请求处理流程（当然也可以去网络抓包），结果发现，curl的GET请求，都带有"Pragma: no-cache"！而wget需要另行指定--no-cache才会。按照squid的默认配置，对client_no_cache是透传的，所以curl永远MISS，除非squid上配置了ignore-reload/reload-into-ims两个参数，才可能强制HIT。
