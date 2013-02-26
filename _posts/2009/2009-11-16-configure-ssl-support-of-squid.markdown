---
layout: post
title: squid的SSL配置
date: 2009-11-16
category: squid
---

公司新进客户，要求加速它的论坛，比较奇怪的是，整个论坛居然都是https协议的网页。所以得做443端口的配置。
如果只是端口，一个https_port 443就够了。麻烦的地方在证书（之前就有客户死活不肯给证书，于是只能给做个端口转发，顶天了算是路由优化，何苦往CDN里投钱……）。
在拿到证书后，squid.conf里添加这么一句，SSL配置就算是完成了。但测试的时候问题可就多多了
{% highlight squid %}
https_port 443 cert=/test_ssl/server.cer key=/test_ssl/server.key defaultsite=bbs.test.com
{% endhighlight %}
客户源站在江苏电信，之前的普通静态加速时，为了更好的达到回源效果，所有的网通节点服务器都采用了二级代理的方式，通过BGP回源。    
在按照普通域名走父方式配置完毕后，wget该客户的论坛首页做测试，所有的网通节点返回的状态码倒是200，可首页文件总字节数，只有209！用IE打开一看，赫然是一个“Hello
World！”暴汗……    
改为直接回源后，立马恢复正常。实在不知道这个你好页面是哪里蹦出来的！    
把这个问题交给百哥和谷婶，大家伙都说只要加上一条never_direct allow all就可以强制转发https协议到上级cache服务器就可以了。但我测试的结果很遗憾——209依然——不可行！

和同事讨论没什么办法，大家认为这个应该是父节点要采用的证书应该是另外一种，因为他既要接受子的请求，又要去源站发起请求。目前情况下，只能取消走父配置，统一直接回源而已。然后缓存，刷新时间等等测试一一通过。唉~
[root@squid1 ~]# wget -S -O /dev/null https://bbs.test.com/attachments/month_0910/20091014_c30caa02ae844a8dbe58M7PIVoPJPjMh.jpg --no-check-certificate
--20:20:28--
https://bbs.test.com/attachments/month_0910/20091014_c30caa02ae844a8dbe58M7PIVoPJPjMh.jpg
Resolving bbs.test.com... 1.2.3.4
Connecting to bbs.test.com|1.2.3.4|:443... connected.
WARNING: cannot verify bbs.test.com's certificate, issued by
`/C=BE/OU=Domain Validation CA/O=GlobalSign nv-sa/CN=GlobalSign Domain Validation CA':
Unable to locally verify the issuer's authority.
HTTP request sent, awaiting response...
HTTP/1.0 200 OK
Date: Mon, 16 Nov 2009 09:02:07 GMT
Server: Apache/2.2.9 (Unix) DAV/2 mod_ssl/2.2.9 OpenSSL/0.9.8h PHP/5.2.6 mod_apreq2-20051231/2.6.0 mod_perl/2.0.4 Perl/v5.10.0
Last-Modified: Wed, 14 Oct 2009 13:52:59 GMT
ETag: "efc217-1801e-475e57b0924c0"
Accept-Ranges: bytes
Content-Length: 98334
Content-Type: image/jpeg
Age: 1
X-Cache: HIT from cdn.21vianet.com
Connection: keep-alive
Length: 98334 (96K) [image/jpeg]
Saving to: `/dev/null'
100%[===================================================================================================================>]
98,334
356K/s   in
0.3s
20:20:34 (356 KB/s) - `/dev/null' saved [98334/98334]

这里要注意两个地方。

第一，刷新配置的匹配字段不再是^http://bbs.test.com/.*而是^https://bbs.test.com/.*，不然的话，age值就按之后的默认配置计数了；    
第二，wget测试的时候，必须使用“--no-check-certificate”参数，否则没法测试；同理，如果是用curl测试，也必须加上“-k”或者“--insecure”参数。

curl的结果类似下面这样：

[root@squid1 ~]# curl -I https://bbs.test.com/attachments/month_0910/20091014_c30caa02ae844a8dbe58M7PIVoPJPjMh.jpg -k
HTTP/1.0 200 OK
Date: Mon, 16 Nov 2009 09:02:07 GMT
Server: Apache/2.2.9 (Unix) DAV/2 mod_ssl/2.2.9 OpenSSL/0.9.8h
PHP/5.2.6 mod_apreq2-20051231/2.6.0 mod_perl/2.0.4
Perl/v5.10.0
Last-Modified: Wed, 14 Oct 2009 13:52:59 GMT
ETag: "efc217-1801e-475e57b0924c0"
Accept-Ranges: bytes
Content-Length: 98334
Content-Type: image/jpeg
Age: 187
X-Cache: HIT from cdn.21vianet.com
Connection: close
