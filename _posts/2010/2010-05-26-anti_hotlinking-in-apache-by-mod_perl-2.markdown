---
layout: post
title: apache防盗链（mod_perl试用二）
date: 2010-05-26
category: web
tags:
  - apache
  - perl
---

上回提到的防盗链方式是在strings上加上key和time，uri本身是不变的，这种方式其实现在不是很主流，主流的方式是将计算得出的加密串直接改在uri的路径里。比如下面将要提到的例子。要求其实和早先那个[squid防盗链](/2010/01/30/anti-hotlinking-in-nginx-lighttpd-squid)的一模一样，就是改成用apache来跑。
Test.pm内容如下：
{% highlight perl %}
package Test;
use strict;
use warnings;
use Socket qw(inet_aton);
use POSIX qw(difftime mktime);
use Digest::MD5 qw(md5_hex);
use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();
use Apache2::Log ();
use Apache2::Request ();
use Apache2::Const qw(DECLINED FORBIDDEN);
sub handler {
    my $r = shift;
    my $s = Apache2::ServerUtil->server;
    my $secret = $r->dir_config('Secret') || '';
    my $uri = $r->uri() || '';
    my $expire = 2 * 3600;
    if ($uri =~ m#^/(d{4})(d{2})(d{2})(d{2})(d{2})/(w{32})(/S+.mp3)$#oi) {
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
}
1;
{% endhighlight %}

然后在httpd.conf中加上如下配置：

{% highlight apache %}
PerlPostConfigRequire /home/apache2/perl/start.pl
SetHandler modperl
PerlTransHandler Test
PerlSetVar Secret abcdef
{% endhighlight %}

这里需要注意几点，根据modperl的处理流程，修改uri的时候，handler还没有走到对文件进行寻址，所以无法区分文件路径等信息，故而 `PerlTransHandler` 配置不能在 `<Directory>` 和 `<Location>` 里面。

而在[试用一](/2010/04/15/anti_hotlinking-in-apache-by-mod_perl)里，核对strings是用的 `PerlAccessHandler`，当时已经确认了uri的文件路径，故而可以在 `<Location>` 里。

另，上面的pm，对错误访问返回的是404，如果需要403，`return FORBIDDEN` 就可以了。

如果想同时根据referer来防盗链，可能要在 `PerlHeaderParserHandler` 阶段在进行一次判定了，这个还在研究，不知道怎么取request-header的信息……
