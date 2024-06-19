---
layout: post
theme:
  name: twitter
title: 获取 Perl 程序中 GET 请求发向的具体 IP
category: perl
---

在运维工作中我们经常需要检测用户访问是否正常，一般来说，直接通过 DNS 客户端获取 A 记录就可以满足需要。不过如果我们可以获得具体连接的 IP 地址，那么就可以缩小问题的判断范围，因为 DNS 的 A 记录通常是有多个的。

AE::HTTP 模块可以返回 sock 给用户进行具体操作，我们可以通过 sock 接口很简单的获得对端的 IP 地址：

```perl
package Web::Checker::Util::HTTP;
use Moo;
use MooX::Types::MooseLike::Base qw/Str Num/;
use AnyEvent::HTTP;
use AnyEvent::Socket;
use AnyEvent;
use Time::HiRes qw/time/;

has peer    => ( is => 'rw', isa => Str );
has reptime => ( is => 'rw', isa => Num );
has clength => ( is => 'rw', isa => Num );
has body    => ( is => 'ro', isa => Str );
has proxy   => ( is => 'ro', isa => Str, default => sub { undef } );
has cv => ( is => 'ro', default => sub { AnyEvent->condvar } );

sub get {
    my ( $self, $url ) = @_;
    $self->cv->begin;
    my $begin = time;
    http_get $url,
      proxy            => $self->proxy,
      # 就是这里发挥了作用，默认应该是直接返回 body 字符串的
      want_body_handle => 1,
      sub {
        my ( $hdl, $headers ) = @_;
        my ( $port, $peer ) =
          AnyEvent::Socket::unpack_sockaddr getpeername $hdl->{fh};
        $self->peer( AnyEvent::Socket::format_address $peer );
        if ( $headers->{Status} =~ /^2/ ) {
            my $end = time;
            $self->reptime( $end - $begin );
            $self->clength( $headers->{'content-length'} );
            $self->cv->end;
        }
      };
    $self->cv->recv;
}

1;
```

其实 AE::HTTP 还可以在 `tcp_connect` 的时候获取 sock，这时候就需要自己用 `AnyEvent::Handle` 写一遍 `AnyEvent::HTTP::tcp_connect` 已经写过的东西了(当然如果你本来就打算干点别的事情，那就是另外一回事情了)~~
