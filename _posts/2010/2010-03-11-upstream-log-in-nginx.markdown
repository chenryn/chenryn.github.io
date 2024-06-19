---
layout: post
theme:
  name: twitter
title: nginx日志（upstream）
date: 2010-03-11
category: nginx
---

作为一个web服务器，我们已经习惯了nginx的类apache日志，即$status。其实nginx的upstream模块下，带有几个变量，却是类squid日志的。他们是：

    $upstream_addr
    $upstream_cache_status
    $upstream_status

当log_format main '$msec ''$remote_addr ''$upstream_cache_status/$upstream_status ''$body_bytes_sent ''$request_method ''$scheme://$http_host$request_uri ''$remote_user ''$upstream_addr ''"$http_referer" ''"$http_user_agent" ';的时候，访问一个可cache的url的log结果如下：

    1268324542.656 127.0.0.1 MISS/200 60 GET http://flv.91091.net/skins/meihong/images/icon_album.gif - 202.102.79.133:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268324544.505 127.0.0.1 HIT/- 60 GET http://flv.91091.net/skins/meihong/images/icon_album.gif - "-" "Wget/1.10.2 (Red Hat modified)"

$upstream_cache_status除了MISS和HIT外，还有EXPIRED、UPDATING和STALE三个赋值。这三个赋值的原文解释如下。

** EXPIRED - expired, request was passed to backend
** UPDATING - expired, stale response was used due to proxy/fastcgi_cache_use_stale updating
** STALE - expired, stale response was used due to proxy/fastcgi_cache_use_stale

这个STALE应该类似TCP_REFRESH_HIT，EXPIRED是TCP_MISS和TCP_REFRESH_MISS，UPDATING有些不好对比了。这个可能跟squid和nginx的传输方式不太同有关。squid对数据，是边从oringin拿边传给client的，而nginx要全部拿完才给。这期间，应该就是UPDATING？？


