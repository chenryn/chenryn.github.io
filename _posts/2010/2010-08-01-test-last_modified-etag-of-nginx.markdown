---
layout: post
title: 郁闷的last-modified和etag试验
date: 2010-08-01
category: CDN
tags:
  - nginx
  - SSI
---

手上有一个伪静态的论坛bbs.example.com，每当有用户回复帖子的时候，提交到r.bbs.example.com，然后由r.bbs.example.com的提示页面replyautojump.jsp延迟3000后调用window.location.href函数返回原来的帖子——期间即完成对该帖的静态化。

为了实效性，之前的配置，将这类html都设定为no-cache。现在考虑到流量和IO的问题，计划希望能够将这类html尽可能的缓存在browser和proxy上，但每次都能采用304的方式，确认帖子的最新情况。对于不太热门的板块，不太热点的帖子，应该能缓存一段时间，减轻webserver的压力；就算是热门，哪怕几十秒钟的缓存，对于全网流量，也是积腋成裘。。。

因为论坛页面上，用SSI方式include了一些广告、点击排名等挂件。所以nginx上设定了ssi on，导致response-header中，没有了last-modified——按照常规，一般是在长期不变的html里include经常改变的shtml，而每次在解析SSI时去读取所有shtml的MTIME然后计算最后一个MTIME来设定成总页面的last-modified，是个比较繁琐且耗资源的做法（网上有lighttpd的patch，就是这么做的），所以包括nginx在内的多数webserver采取了比较简便的方法，即取消掉last-modified输出。参见nginx/src/http/module/ngx_http_ssi_filter_module.c第361行：

{% highlight c %}
static ngx_int_t
ngx_http_ssi_header_filter(ngx_http_request_t *r)
{
    ……
    if (r == r->main) {
        ngx_http_clear_content_length(r);
        ngx_http_clear_last_modified(r);
        ngx_http_clear_accept_ranges(r);
    }
    return ngx_http_next_header_filter(r);
}
{% endhighlight %}

而我这系统的情况，可能广告1天一变，排行15分钟一变，都远远慢于页面本身的更新速度，完全可以将html的MTIME认定为总页面的last-modified。
注释掉相应源码，重新编译nginx后进行试验，在使用F5刷新的时候，果然发送了IMS，这一步成功了；可是回复帖子后，因为是跳转方式，浏览器直接采用本地cache，而不会发送IMS，所以还是看到旧页面。。。
<hr />
因为测试平台上正好有另一个端口运行着httpd，不小心发现在跳转时如果有etag的话，还是会发送INM确认。于是今天开始试验往nginx上加etag。
从git上下载etag模块源码，采用add-module方式重编译nginx，启动后先试验直接从nginx访问。确认其在回复跳转时发送了INM，然后加上前段squid，怪事出现了——虽然response-header中确实有etag，刷新网页时request-header中却一直没有出现if-none-match！！

返回查看squid和nginx的日志。squid中一直记录的是TCP_REFRESH_MISS/200，nginx上更离谱！304时传输的文件大小居然比200时还大！见下：
    127.0.0.1 - - [01/Aug/2010:15:18:18 +0800] "GET /data/thread/1011/2716/14/71/9_1.html HTTP/1.0" 200 14823 "-" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)" "124.200.241.143"
    124.200.241.143 - - [01/Aug/2010:15:18:57 +0800] "GET /data/thread/1011/2716/14/71/9_1.html HTTP/1.1" 304 23459 "-" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)" "-"
<hr />
最后作为尝试，再打开SSI的last-modified同时加载etag编译了一次，试验结果，发现和没etag时一模一样，只见IMS不见INM。可是squid明明在2.6.1开始就支持etag了，怪哉~~

下次有时间，再试试lighttpd的etag吧~


