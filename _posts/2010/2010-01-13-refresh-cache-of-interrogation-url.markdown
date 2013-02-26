---
layout: post
title: squid刷新缓存
date: 2010-01-13
category: CDN
tags:
  - squid
---

这篇博文的起因是最近犯的一个低级错误。某客户要求立刻刷新掉一批url。格式是http://a.b.com/index.jsp?pid=123456&id=654321这样的。
我也没多想，上去就执行“squidclient -p 80  -m purge
http://a.b.com/index.jsp?pid=123456&id=654321”。结果硬是刷不掉……明明访问源站已经没有这个url了。我wget居然还能MISS/200~~~
直到同事提醒。才赫然发现其实我一直在purge和wget的，不是http://a.b.com/index.jsp?pid=123456&id=654321，而是http://a.b.com/index.jsp?pid=123456。linux把url里的&当作后台运行的命令执行了……而access.log中为了安全又没记录?后的具体参数，于是傻傻的跟客户客服扯皮了N久……
“squidclient -p 80  -m purge 'http://a.b.com/index.jsp?pid=123456&amp;amp;id=654321'”这么一刷立刻就好了~~
由此告诫自己，以后一定要严谨行事，引号最好还是要养成习惯都给带上~~

以下具体总结摘录squid缓存刷新的几种办法，随便感谢百度，悼念谷歌：

第一种——当squid的refresh_pattern未使用任何options，即squid缓存遵循http协议精神时有效。原理是模拟no-cache头的request（即ctrl+F5刷新）：
【nnd，一帖就错误，单独放一个帖子，大家看下一贴吧】

第二种，采用PURGE方式刷新，request的header如下：

PURGE http://www.lrrr.org/junk HTTP/1.0
Accept: */*

脚本类似第一种方法，修改其中的HEAD为PURGE即可：

$head = "PURGE $url_component['path'] HTTP/1.1\r\n";

按照《squid中文权威指南》的说法，当squid收到purge指令的时候，也是采用head和get的方式去处理请求，然后找到cache的文件进行删除的。

第三种，采用多播HTCP包。这是 MediaWiki 目前正在使用的方法，当wiki 更新时用于更新全球的 Squid缓存服务器，实现原理为：发送 PURGE 请求到特定的多播组，所有Squid服务器通过订阅该多播组信息完成删除操作，这种实现方式非常高效，避免了 Squid 服务器处理响应和建立 TCP连接的开销。参考资料： Multicast HTCP purging。

第五种，小工具：<a href="http://www.wa.apana.org.au/~dean/squidpurge/">http://www.wa.apana.org.au/~dean/squidpurge/</a>
wget http://www.wa.apana.org.au/~dean/sources/purge-20040201-src.tar.gz
tar zxvf purge-20040201-src.tar.gz
cd purge
make
./purge -help
    ### Use at your own risk! No guarantees whatsoever. You were warned. ###
    $Id: purge.cc,v 1.17 2000/09/21 10:59:53 cached Exp $
    Usage: purge [-a] [-c cf] [-d l] [-(f|F) fn | -(e|E) re] [-ph[:p]]
    [-P #] [-s] [-v] [-C dir [-H]] [-n]
    -a display a little rotating thingy to indicate that I am alive
    (tty only).
    -c c squid.conf location, default
    "/usr/local/squid/etc/squid.conf".
    -C dir base directory for content extraction (copy-out mode).
    -d l debug level, an or of different debug options.
    -e re single regular expression_r_r per -e instance (use
    quotes!).
    -E re single case sensitive regular expression_r_r like -e.
    -f fn name of textfile containing one regular
    expression_r_r per line.
    -F fn name of textfile like -f containing case sensitive REs.
    -H prepend HTTP reply header to destination files in copy-out
    mode.
    -n do not fork() when using more than one cache_dir.
    -p h:p cache runs on host h and optional port p, default is
    localhost:3128.
    -P # if 0, just print matches; otherwise or the following purge
    modes:
    0x01 really send PURGE to the cache.
    0x02 remove all caches files reported as 404 (not found).
    0x04 remove all weird (inaccessible or too small) cache
    files.
    0 and 1 are recommended - slow rebuild your cache with other modes.
    -s show all options after option parsing, but before really
    starting.
    -v show more information about the file, e.g. MD5, timestamps and
    flags.

使用示例：

1. 清除URL中包含jackbillow.com的所有缓存
    ./purge -p 127.0.0.1:80 -P 1 -se 'jackbillow.com'
2. 清除 URL 以“.mp3”结尾的缓存文件，例如：http://www.dzend.com/abc/test.mp3
    ./purge -p 127.0.0.1:80 -P 1 -se '.mp3$'

第五种，张宴的脚本clear_squid_cache.sh。（老小注：还是这个熟悉，呵呵）
{% highlight bash %}
#!/bin/sh
squidcache_path="/data1/squid/var/cache"
squidclient_path="/usr/local/squid/bin/squidclient"
grep -a -r $1 $squidcache_path/* | strings | grep "http:" | awk -F'http:' '{print "http:"$2;}' >cache_list.txt
for url in `cat cache_list.txt`; do
    $squidclient_path -m PURGE -p 80 $url
done
{% endhighlight %}

据说：经测试，在DELL 2950上清除26000个缓存文件用时2分钟左右。平均每秒可清除缓存文件177个。
看到了吧，网上流传的这个脚本里，$url也没有用""引起来，所以用这个sh刷新的时候，也失败了……
