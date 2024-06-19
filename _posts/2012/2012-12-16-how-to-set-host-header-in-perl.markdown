---
layout: post
theme:
  name: twitter
title: perl发起HTTP请求时如何设置Host头
category: perl
---

之所以写这么个内容，是今天突然发现之前有个脚本的效果完全不对。这个脚本是用 Furl 模块发 HTTP 请求。看 POD 的说明，以为这样写是生效的：

```perl
    use HTTP::Request;
    use Furl;
    my $r = HTTP::Request->new( GET => "http://192.168.0.2/path/to/file" );
    $r->header( Host => "www.example.com" );
    my $furl = Furl->new();
    my $res = $furl->request($r);
    say $res->code();
```

但是随后在 192.168.0.2 上发现日志记录中，Host 并没有修改成 www.example.com 。

然后尝试了各种 POD 上介绍的 header 写法，包括在 new HTTP::Request 的时候使用 `[Host => "www.example.com"]` 参数，在 `$furl->request` 的时候使用 `headers => [Host => "www.example.com"]` 参数。结果都一样。

然后只能改思路，用设置 proxy 的办法。结果发现 Furl 模块的 proxy 不可用……

POD 上是说直接在 new 的时候传递 %args 或者 \%args 就行。但是我使用的时候发现直接会报错：

    Passed malformed URL: 192.168.0.2

最后只能放弃使用 Furl 模块，改回古老的 LWP 模块。LWP 与 Coro 配合如下：

```perl
    use Coro;
    use LWP::Protocol::Coro::http;
    use LWP::UserAgent;
    sub co_http_get {
        my ( $domain, $urlpath, $iplist ) = @_;
        my @coros;
        my $msg = '';
        my $ua = LWP::UserAgent->new();
        foreach my $ip ( @{$iplist} ) {
            push @coros, async {
                $ua->proxy('http', "http://$ip:3128/");
                my $res = $ua->get("http://$domain$urlpath");
                $msg .= "$ip: " . $res->code() . "\n";
            }
        }
        $_->join for @coros;
        return $msg;
    }
    print co_http_get("www.example.com", "/path/to/file", [qw(192.168.0.1 192.168.0.2)]);
```
