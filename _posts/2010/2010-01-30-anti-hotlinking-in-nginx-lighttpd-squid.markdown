---
layout: post
title: 防盗链进阶（nginx、lighttpd和squid类比）
date: 2010-01-30
category: CDN
tags:
  - perl
  - php
  - nginx
  - squid
  - lighttpd
---

在折腾squid的rewrite.pl时，参考的是公司原有的一个防盗链脚本。如下：
```perl
#! /usr/bin/env perl
use strict;
use Digest::MD5 qw(md5_hex);
use POSIX qw(difftime mktime);
$| = 1;
my $errUrl = "http://www.test.com/no_such_url.html";
my $secret = "123456";
my $expired = 7200;
while () {
    my ($uri, $client, $ident, $method) = split;
    print "$errUrln" and next unless ($uri =~ m#^(http://w*.?test.com)/(d{4})(d{2})(d{2})(d{2})(d{2})/(w{32})(/.+.mp3)$#i);
    my ($domain, $year, $mon, $mday, $hour, $min, $md5, $path) = ($1, $2, $3, $4, $5, $6, $7, $8);
    print "$errUrl\n" and next if $year < 1990 or $mon == 0 or $mon > 12 or $mday == 0 or $mday > 31 or $hour > 23 or $min > 59;
    print "$errUrl\n" and next if abs(difftime((int(time() / 100) * 100), mktime(00, $min, $hour, $mday, $mon - 1, $year - 1900))) > $expired;
    $path =~ s#%(..)#pack("c", hex($1))#eg;
    print "$errUrl\n" and next if $md5 ne md5_hex($secret . $year . $mon . $mday . $hour . $min . $path);
    print $domain . $path, "\n";
}
```
今天在网上看到lighttpd相似的配置。lighttpd自带mod_secdownload模块实现这种防盗链方法。具体配置及php代码如下例（详见http://trac.lighttpd.net/trac/wiki/Docs%3AModSecDownload）：
```php
<?
$secret = "verysecret";  //加密字符串，必须跟lighttpd.conf里边保持一致
$uri_prefix = "/dl/";    //虚拟的路径，必须跟lighttpd.conf里边保持一致
# filename
$f = "/secret-file.txt";  //实际文件名，必须要加"/"斜杠
# current timestamp
$t = time();
$t_hex = sprintf("%08x", $t);
$m = md5($secret.$f.$t_hex);
# generate link
printf('%s', $uri_prefix, $m, $t_hex, $f, $f);
?>
```
lighttpd配置文件:    
server.modules = ( ..., "mod_secdownload", ... )
secdownload.secret          = "verysecret"
secdownload.document-root   = "/home/www/servers/download-area/"
secdownload.uri-prefix      = "/dl/"
secdownload.timeout         = 10

nginx也有类似功能，不过不是自带，secure_link_module模块，打补丁需要重编译：

wget http://www.sbear.cn/wp-content/uploads/2009/09/nginx-secure-link-ttl.patch
cd nginx-0.7.62
patch -p1 < ../nginx-secure-link-ttl.patch
./configure --with-http_secure_link_module
……
具体配置及php例子如下（详见http://wiki.nginx.org/NginxHttpSecureLinkModule）：
```nginx
location /down/ {
    secure_link_secret "sbear.cn";  //密钥
    secure_link_ttl on;
    root /data/test/down;
    if ($secure_link = "") {
        return 403;
}
    rewrite ^ /$secure_link break;
}
```
```php
<?php
define(URL_TIMEOUT, 3600); //这里设置过期时间单位是秒
$prefix = "<a href="http://www.sbear.cn/down&quot;;">http://www.sbear.cn/down";</a>
$protected_resource = "test.exe";
$secret = "sbear.cn";  //密钥
$time = pack('N', time() + URL_TIMEOUT);
$timeout = bin2hex($time);
$hashmac = md5( $protected_resource . $time . $secret );
$url = $prefix . "/" . $hashmac . $timeout . "/" . $protected_resource;
echo "down";
echo time();
?>
```

那不打补丁，有什么防盗链的办法么？当然有。nginx和lighttpd都支持最简单的referer判断。

nginx有ngx_http_referer_module模块，和apache、squid一样可以rewrite，配置如下：
```nginx
location ~* .(gif|jpg|png)$ {
valid_referers none blocked www.test.com baidu.com;
    if ($invalid_referer) {
        rewrite ^/ http://www.test.com/error.html;
    }
}
```

lighttpd配置如下：

$HTTP["referer"] !~ "^(http://.*.(test.com|baidu.cn))"
{
    $HTTP["url"] =~ ".(jpg|jpeg|png|gif|rar|zip|mp3|swf|flv|wmv|rm|avi)$" {
        url.redirect = (".*"    => http://www.test.com/")
    }
}
不过还是那句话，这个功能破解起来确实太容易，呵呵~

除了上面说的NginxHttpSecureLinkModule，还有另一个模块ngx_http_accesskey_module，其工作原理是根据client的IP，加上配置定义的key，生成32位MD5值，然后进行匹配。详见http://wiki.codemongers.com/NginxHttpAccessKeyModule，不过我这居然打不开……只好详见网友博客了：
wget <a href="http://wiki.nginx.org/File:Nginx-accesskey-2.0.3.tar.gz">http://wiki.nginx.org/File:Nginx-accesskey-2.0.3.tar.gz</a>
tar zxvf Nginx-accesskey-2.0.3.tar.gz
sed -i 's/$HTTP_ACCESSKEY_MODULE/ngx_http_accesskey_module/g nginx-accesskey/config
./configure --add-module=/path/to/nginx-accesskey
#配置文件
location /download {
    accesskey on;
    accesskey_hashmethod md5;
    accesskey_arg “key”;
    accesskey_signature “mypass$remote_addr”;
}
//php测试页面，$output_add_key正常，$output_org_url返回403//
<?
$ipkey= md5("mypass".$_SERVER['REMOTE_ADDR']);
$output_add_key="<a href="http://www.example.cn/download/G3200507120520LM.rar?key=">http://www.example.cn/download/G3200507120520LM.rar?key="</a>.$ipkey.">download_add_key<br
/>";
$output_org_url="<a href=<a href="http://www.example.cn/download/G3200507120520LM.rar">http://www.example.cn/download/G3200507120520LM.rar</a>>download_org_path<br
/>";
echo $output_add_key;
echo $output_org_url;
?>
而另一个博客这么说：
wget http://www.ieesee.net:8080/~uingei/nginx-accesskey-2.0.3.diff.bz2
cd nginx-0.7.14
bzcat ../nginx-accesskey-2.0.3.diff.bz2 | patch -p1
./configure --with-http_accesskey_module ...
根据我的观察，这个应该是最初的办法。另，该博客说sec_link是nginx0.7.18后加的官方模块。


