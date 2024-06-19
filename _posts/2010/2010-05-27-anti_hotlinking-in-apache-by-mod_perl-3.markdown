---
layout: post
theme:
  name: twitter
title: apache防盗链（mod_perl试用三）
date: 2010-05-27
category: web
tags:
  - apache
  - perl
---

客户的要求，还剩下最后一步，就是referer限定。对于apache，有Mod_rewrite现成的可用：
```apache
RewriteEngine on
RewriteCond %{HTTP_REFERER} !^http://(www.)?test.com/.*$ [NC]
RewriteRule .mp3$ http://www.test.com/ [R=301,L]
```
不过既然之前已经用了perl，这里就一口气把perl写完吧：
```perl
sub handler {
    my $r = shift;
    my $s = Apache2::ServerUtil->server;
    my $secret = $r->dir_config('Secret') || '';#这里可以写成$r->dir_config->{Secret}
    my $uri = $r->uri() || '';
    my $expire = 2 * 3600;
+    my $referer = $r->headers_in->{Referer} || '';#这里却不可以写成$r->headers_in(Referer)，会报错“argument is not a blessed reference (expecting an APR::Table derived object)，不知道为什么？
+    if ($referer =~ m#^http://music.test.com#oi){
    if ($uri =~ m#^/(d{4})(d{2})(d{2})(d{2})(d{2})/(w{32})(/S+.mp3)$#oi){
        my ($year, $mon, $mday, $hour, $min, $md5, $path) = ($1, $2, $3, $4, $5, $6, $7);
        my $str = md5_hex($secret . $year . $mon . $mday . $hour . $min . $path);
        my $reqtime = mktime(00, $min, $hour, $mday, $mon - 1, $year - 1900);
        my $now = time;
        if ( $now - $reqtime < $expire){
                if ($str eq $md5) {
                    $r->uri("$path");
                    return Apache2::Const::DECLINED;
                }
        }
   }
+}
}
```
简单两句话，就ok了。测试如下：
    [27/May/2010:22:45:00 +0800] &quot;GET /201005272218/ceaf967f6bcf9a185a3287b2e3ff5a02/smg/123.mp3 HTTP/1.0&quot; 200 - <a href="http://music.test.com/">http://music.test.com</a> &quot;Wget/1.10.2 (Red Hat modified)&quot;
    [27/May/2010:22:45:05 +0800] &quot;GET /201005272218/ceaf967f6bcf9a185a3287b2e3ff5a02/smg/123.mp3 HTTP/1.0&quot; 404 - <a href="http://www.baidu.com/">http://www.baidu.com</a> &quot;Wget/1.10.2 (Red Hat modified)&quot;
    [27/May/2010:22:45:17 +0800] &quot;GET /201005272218/ceaf967f6bcf9a185a3287b2e3ff5a03/smg/123.mp3 HTTP/1.0&quot; 404 - <a href="http://music.test.com/">http://music.test.com</a> &quot;Wget/1.10.2 (Red Hat modified)&quot;
对于各种非正常的访问，都返回404 NOT FOUND。
如果想要返回403 ACCESS DENIED的话，经测试，在前面这些handler是没法做到的，必须在perlaccesshandler里才能return FORBIDDEN。那只能在之前的transhandler里统一改写uri成一个约定字符串，然后在access中再匹配拒绝。很麻烦。。。
