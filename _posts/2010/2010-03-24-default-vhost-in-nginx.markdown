---
layout: post
title: nginx的默认主机头问题
date: 2010-03-24
category: nginx
---

今天发现nginx做多域名混跑的proxy_cache时有一个小问题：当一个非加速server_name的请求到达的时候，nginx不会像squid那样返回一个ERR_DNS_FAIL，反而假装很正常的返回一个页面：
{% highlight nginx %}
http {
    server {
        server_name www.aaa.com;
        proxy_pass http://1.1.1.1;
    }
    server {
        server_name www.bbb.com;
        proxy_pass http://2.2.2.2;
    }
}
{% endhighlight %}
访问www.ccc.com的时候，nginx毫不犹豫的把www.aaa.com的页面内容返回给了client。在日志里记录：

    MISS/200 GET http://www.ccc.com/ 1.1.1.1:80

如果把aaa和bbb的server{}顺序倒换，那ccc的回源地址就变成了2.2.2.2……

也就是说，解析不出、定义不到的域名请求，自动返回排在第一位的server内容。

解决办法也容易，在最上头，也定义一个自己的server，就可以了：
{% highlight nginx %}
http {
    server {
        root /cache;
        rewrite ^(.*) /error.htm permanent;
    }
    server {
        ……
    }
}
{% endhighlight %}
至于这个error.htm，有没有都一样，反正有就是301，没有就是404~~

后面的web服务器为什么不检查Host直接给出内容，也是让人很郁闷的一点。或许IIS就是如此？
