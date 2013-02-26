---
layout: post
title: cache驻留时间（五、Etag）
date: 2009-11-21
category: CDN
tags: 
  - cache
---

浏览器的请求中，除了用If-Modified-Since去比对Last-Modified以外，还有另一个标签Etag，这个东东是web服务器比较有用的，squid倒没什么。不过大文件下载加速也有采用apache的系统，一并算在cache缓存里头讲吧：

Etag是为了更好的区分文件过期的标签。比如Last-Modified吧，如果我在一秒钟内更新两次这个文件，他的Last-Modified时间还是一样的。但Etag值不一样。听起来很浪费的样子，呵呵~~

Etag是由文件的inode、mtime、size三个数据通过计算得出来的字符串。这三个都可以通过stat命令查看得到。但问题就来了——一个LVS下挂了七八台RealServer，size固然得一样，mtime只要同步没有问题，也是一样，可这个inode，几乎就不太可能一样了——也就是说，当浏览器的请求被LVS转发到A服务器上时，取得了一个Etag值，一旦刷新重复请求，可能LVS又转发到B服务器，而这个文件在B服务器上计算出的Etag值是另一个。浏览器将判断文件不一致，重新下载！

这种情况，于网民，是用户体验度下降；于网站，是带宽重复占用；于服务器，是无效负载……

不过我们既然知道了原理，解决起来也很简单，只需要在apache的配置中，规定Etag的计算来源就行了。

默认的Etag计算是：FileETag INode MTime Size，如果改全局，只要改成FileETag MTime Size就可以了。如果是下面的某一部分，则写成FileETag -INode也行。
header信息就说到这里吧，最后提供一个[wiki](http://en.wikipedia.org/wiki/List_of_HTTP_headers)

