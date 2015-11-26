---
layout: post
title: AnyEvent::HTTPD和AnyEvent::HTTP使用实例
category: perl
---
很简单的一个实例，就是开一个端口接受url请求，然后向squid提交这个url的刷新。
```perl
use AnyEvent::HTTPD;
use AnyEvent::HTTP;

my $httpd = AnyEvent::HTTPD->new (port => 9090);
my $ip = "127.0.0.1";

$httpd->reg_cb (
    '/' => sub {
        my ($httpd, $req) = @_;
        my $urlpath = $req->url->path;
        http_request PURGE => "http://${ip}${urlpath}", headers=> { "host"=>"host.domain.com"}, sub {
            my ($body, $hdr ) = @_;
            $req->respond(["$hdr->{'Status'}","$hdr->{'Reason'}",{'Content-Type' => 'text/html'}]);
        };
    },
);

$httpd->run;

```

注意安装AnyEvent::HTTPD的时候，test需要Test::POD，但是Makefile.PL上没写，所以要先行安装。

