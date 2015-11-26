---
layout: post
title: apache防盗链(modperl试用)
date: 2010-04-15
category: web
tags:
  - apache
  - perl
---

客户需求如下：

在web请求视频时，按算法生成密文和明文串，然后依规则组成最终的url请求；

算法规则：

用如下三个关键词生成 MD5 密文：

1. 自定义密钥：abcde.；
2. 视频文件真实路径，即/path/to/file.rmvb；
3. 请求时间，以当前UNIX时间换算为十六进制字符串，并作为明文；

最终url格式是 `http://www.test.com/path/to/file.rmvb?key=1234567890abcdefghijklmnopqrstuy&t=1234abcd` 这样。

要求失效时间为8小时。

这个需求和之前一次相当类似，不过上回是squid，这次是apache。同样采用perl脚本进行防盗链设置，apache需要使用modperl模块。

首先安装perl模块：

```bash
wget http://perl.apache.org/dist/mod_perl-2.0-current.tar.gz
tar zxvf mod_perl-2.0-current.tar.gz
cd mod_perl-2.0-current.tar.gz
perl Makefile.PL MP_APXS=/home/apache2/bin/apxs
make && make install
echo "LoadModule perl_module modules/mod_perl.so" >> /home/apache2/conf/httpd.conf
perl -MCPAN -e shell
>install Apache2::Request
>look Apache2::Request
rm -f configure
rm -f apreq2-config
./buildconf
perl Makefile.PL
make && make install
exit
#因为64位系统的libexpat.so有问题，编译libapreq2会出问题，只好如此强制安装
echo "LoadModule apreq_module modules/mod_apreq2.so" >> /home/apache2/conf/httpd.conf
```

因为libapreq2.so安装在/home/apache2/lib/下了，所以需要`echo "/home/apache2/lib" >/etc/lo.so.conf.d/apache.conf`，然后ldconfig。

修改httpd.conf，加入如下设置：

```
PerlPostConfigRequire /home/apache2/perl/start.pl
<Location /smg>
SetHandler modperl
PerlAccessHandler DLAuth
PerlSetVar ShareKey abcde.
</Location>
```

然后mkdir /home/apache2/perl/，在其中创建start.pl和DLAuth.pm两个文件。start.pl文件内容如下：

```perl
use strict; 
use lib qw(/home/apache2/perl);
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();
use Apache2::Log ();
use Apache2::Request ();
1; 
```

DLAuth.pm文件内容如下：

```perl
package DLAuth;
use strict;
use warnings;
use Socket qw(inet_aton);
use POSIX qw(difftime strftime);
use Digest::MD5 qw(md5_hex);
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();
use Apache2::Log ();
use Apache2::Request ();
use Apache2::Const -compile => qw(OK FORBIDDEN);
sub handler {
    my $r = shift;
    my $s = Apache2::ServerUtil->server;
    my $shareKey = $r->dir_config('ShareKey') || '';
    my $uri = $r->uri() || '';
    my $args = $r->args() || '';
    my $expire = 8 * 3600;
    if ($args =~ m#^key=(\w{32})&t=(\w{8})$#i) {
        my ($key, $date) = ($1, $2);
        my $str = md5_hex($shareKey . $uri . $date)
        my $reqtime = hex($date);
        my $now = time;
        if ( $now - $reqtime < $expire) {
            if ($str eq $key) {
                return Apache2::Const::OK;
            } else {
                $s->log_error("[$uri FORBIDDEN] Auth failed");
                return Apache2::Const::FORBIDDEN;
            }
        }
    }
    $s->log_error("[$uri FORBIDDEN] Auth failed");
    return Apache2::Const::FORBIDDEN;
}
1;
```

就可以了。

apachectl restart。测试一下，先用perl自己生成一个测试链接：

```perl
#!/usr/bin/perl -w
use Digest::MD5 qw(md5_hex);
my $key = "bestv.";
$path = shift(@ARGV);
my $date = sprintf("%x",time);
$result = md5_hex($key . $path . $date);
my $uri = "http://127.0.0.1$path?key=$result&t=$date";
print $uri;
```

运行 `./url.pl /smg/abc.rmvb` 生成 `http://127.0.0.1/smg/abc.rmvb?key=4fb6b4e6a0ec484aea98fa727fc7149d&t=4bc7dd5a`，然后 `wget -S -O /dev/null "http://127.0.0.1/smg/abc.rmvb?key=4fb6b4e6a0ec484aea98fa727fc7149d&t=4bc7dd5a"`，返回 200 OK;任意修改 t 为 12345678，再 wget，返回 403 Forbidden。`error_log` 显示如下：

    [Fri Apr 16 11:47:06 2010] [error] [/smg/abc.rmvbkey=4fb6b4e6a0ec484aea98fa727fc7149d&t=12345678 FORBIDDEN] Auth failed
