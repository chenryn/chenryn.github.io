---
layout: post
title: nginx_perl试用
date: 2011-12-12
category: nginx
tags:
  - perl
  - nginx
---

因为空闲时间比较多，所以在CPAN上乱翻，看到了nginx_perl这个项目(原名Nginx::Engine)，现在托管在github.com上。地址见：
<https://github.com/zzzcpan/nginx-perl>

这个模块的目的，是在nginx内置官方perl模块的基础上，实现一系列异步非阻塞的api。用connector/writer/reader完成类似proxy的功能（这里因为是交给perl完成，所以不单单局限在http上了），用take_connection/give_connection完成类似websocket的功能，用ssl_handshaker完成ssl的解析，用timer完成定时器，用resolver完成域名解析…使用方法简单来说，就是用main_count_inc/finalize_request控制计数器，用NGX_READ/NGX_WRITE/NGX_CLOSE等控制callback。

其他内容和apache的mod_perl，或者nginx.org的perl类似。最新版的POD地址见：<http://zzzcpan.github.com/nginx-perl/Nginx.html>

最后举例一个自己写的简单的例子：

{% highlight perl %}
package HelloWorld;
use Nginx;
use strict;
#用来在nginx启动的时候做的事情，这里单纯显示一下
sub init_worker {
    warn 'nginx_perl start [OK]';
};
#这里是nginx的http模块中调用的handler，alexander有计划改成tcp级别的
sub handler {
    my $r = shift;
#增加主循环的计数器
    $r->main_count_inc;
#使用非阻塞的连接器连接127.0.0.1的80端口，10秒超时
    ngx_connector '127.0.0.1', 80, 10, sub {
#如果连接出问题，会记录在$!中
        if ($!) {
            $r->send_http_header('text/html');
            $r->print("Connection failed, $!\n");
            $r->send_special(NGX_HTTP_LAST);
#不管怎么处理这次连接，最后一定要记得用$r->finalize_request()，会decrease之前$r->main_count_inc;里加上的计数。
            $r->finalize_request(NGX_OK);
            return NGX_CLOSE;
        };
#返回$c是建立的连接
        my $c = shift;
        my $req_buf = "GET /index.php HTTP/1.0\x0d\x0a".
              "Host: chenlinux.com\x0d\x0a".
              "Connection: close\x0d\x0a".
              "\x0d\x0a";
#这里记住定义buffer的时候不要搞成undef了，会报段错误的，不过俄国佬回信说他修复了
        my $res_buf = '';
#非阻塞写入，超时10秒
        ngx_writer $c, $req_buf, 10, sub {
            if ($!) {
                 ......
            };
            $req_buf = '';
#之前的buffer测试就是这里，如果加一个warn，就不会报错……汗
#warn "$req_buf\n$res_buf\n";
#写入完成后，开始调用读取
            return NGX_READ;
        };
#读取到buffer，最短0字节，最长8000字节，超时10秒
        ngx_reader $c, $res_buf, 0, 8000, 10, sub {
            if ($!) {
            ......
            }
            $r->send_http_header('text/html');
            $r->print($res_buf);
            $r->send_special(NGX_HTTP_LAST);
            $r->finalize_request(NGX_OK);
            return NGX_CLOSE;
        };
#这个是connector的语句，表示连接成功后调用写入
        return NGX_WRITE;
    };
#各个非阻塞调用完成后的返回，NGX_DONE只能用在http的handler里，不能在ngx_*r里用，里面请用NGX_CLOSE。
    return NGX_DONE;
};
1;{% endhighlight %}

另：源码中带有一个真正的反向http的例子Nginx::Util和一个Redis的例子。并且与nodejs读取redis的性能做了对比。可以参见~~

<strong style="display:block;margin:12px 0 4px"><a href="http://www.slideshare.net/chenryn/perlnginx" title="Perl在nginx里的应用" target="_blank">Perl在nginx里的应用</a></strong>
