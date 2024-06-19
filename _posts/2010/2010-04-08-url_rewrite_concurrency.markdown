---
layout: post
theme:
  name: twitter
title: url_rewrite_concurrency
date: 2010-04-08
category: squid
---

squid的重定向，我看网上一般都采用 `redirect_children` (即 `url_rewrite_children`)。估计是因为中文权威指南的原因吧。不过中文权威指南还是2.5版的时候出的。有些新东西没有。比如 `squid.conf.default` 中提供的另一种 `url_rewrite_concurrency`。

官方使用说明如右：<http://wiki.squid-cache.org/Features/Redirectors#How_do_I_make_it_concurrent.3F>

简单的说，就是开启 `url_rewrite_concurrency` 后，squid传递给rewriter的流由四个域增加为五个——最前头多了一个ID。然后rewriter返回的，也就有两个域，ID和uri。

简单修改一下原来的脚本如下即可：
```perl
#!/usr/bin/perl -wl
use strict;
$|=1;
while () {
    my ($id,$url,$client,$ident,$method) = ( );
    ($id, $url, $client, $ident, $method) = split;
    if ($url =~m#^(.*)(?.*)#i) {
        my ($domain,$option) = ($1,$2);
        print "$id $domain\n";
    } else {
        print "$id\n";
    }
}
```
然后squid.conf里修改如下：
```squid
acl rewriteurl url_regex -i ^http://drag.g1d.net/.*.mp40drag?
url_rewrite_access deny !rewriteurl
url_rewrite_program /home/squid/etc/redirect.pl
#url_rewrite_children 10
url_rewrite_concurrency 10
```
