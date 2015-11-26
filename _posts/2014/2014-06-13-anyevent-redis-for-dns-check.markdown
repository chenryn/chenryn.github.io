---
layout: post
title: 用 Redis 做分布式 DNS/HTTP 检测汇总系统
category: perl
tags:
  - monitor
  - redis
  - anyevent
---

一年前搞的一套小脚本，今天翻博客发现没发过，现在发上来好了。主要背景是这样：考虑到有 DNS 和 HTTP 劫持需要监控，但是很多 DNS 服务器对非本区域本运营商的来源请求是拒绝做出响应的，所以得把监控点分散到各地去。其实做这个事情用 nagios 的分布式就足够了，不过如果想做即时触发的紧急任务，就算在 nagios 页面上点击立刻执行，到返回全部结果也得有一阵子。所以选择了自己写一套分布式的异步系统。

中控端脚本如下：

```perl
#!/usr/bin/perl
use Modern::Perl;
use AnyEvent;
use AnyEvent::Redis::RipeRedis;
use Storable qw/freeze thaw/;
use YAML::Syck;
use utf8;
my $area = $ARGV[0];
my $domain = 'fmn.xnimg.cn';
my $master = '10.4.1.21';
my $cv     = AnyEvent->condvar;
my $redis  = AnyEvent::Redis::RipeRedis->new(
    host     => $master,
    port     => 6379,
    encoding => 'utf8',
);
my $dnslist = LoadFile("DNS.yml");
for my $isp ( sort keys %$dnslist ) {
    if ( defined $area ) {
        next unless defined $dnslist->{$isp}->{$area};
        say $area, $isp, join ", ", @{ $dnslist->{$isp}->{$area} };
        my $data = freeze({ domain => $domain, dnslist => $dnslist->{$isp}->{$area} });
        $redis->publish( 'task', $data );
    } else {
        for my $list ( sort keys %{ $dnslist->{$isp} } ) {
            my $data = freeze({ domain => $domain, dnslist => $dnslist->{$isp}->{$list} });
            $cv->begin;
            $redis->publish( 'task', $data );
        }
    }
}
$redis->subscribe(
    qw( report ),
    {
        on_done => sub {
            my $ch_name  = shift;
            my $subs_num = shift;
            print "Subscribed: $ch_name. Active: $subs_num\n";
        },
        on_message => sub {
            my $ch_name = shift;
            my $msg     = thaw( shift );
            printf "%s A %s @%s in %s got %s length %s\n", $domain, $msg->{ip}, $msg->{dns}, $msg->{local}, $msg->{status}, $msg->{len};
            $cv->end;
        },
        on_error => sub {
            print @_;
        },
    }
);
$cv->recv;
```

分布在各地的客户端脚本如下：

```perl
#!/usr/bin/perl
use Modern::Perl;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::DNS;
use AnyEvent::Redis::RipeRedis;
use AnyEvent::HTTP;
use Storable qw/freeze thaw/;
use Digest::MD5 qw/md5_hex/;
use utf8;
my $master = '10.4.1.21';
my $local  = '192.168.0.2';
my $cv     = AnyEvent->condvar;
my $redisr = AnyEvent::Redis::RipeRedis->new(
    host          => $master,
    port          => 6379,
    encoding      => 'utf8',
);
my $redisp = AnyEvent::Redis::RipeRedis->new(
    host          => $master,
    port          => 6379,
    encoding      => 'utf8',
);
$redisr->subscribe(
    'task',
    {
        on_done => sub {
            my $ch_name  = shift;
            my $subs_num = shift;
            print "Subscribed: $ch_name. Active: $subs_num\n";
        },
        on_message => sub {
            my $ch_name = shift;
            my $msg     = thaw(shift);
            for my $dns ( @{ $msg->{dnslist} } ) {
                resolv( $dns, $msg->{domain} );
            }
        },
        on_error => sub {
            my $err_msg  = shift;
            my $err_code = shift;
            print "Error: ($err_code) $err_msg\n";
        },
    }
);
$cv->recv;
sub resolv {
    my ( $dns, $domain ) = @_;
    return unless $dns =~ m/^\d+/;
    my $resolver =
      AnyEvent::DNS->new( server => [ AnyEvent::Socket::parse_address $dns ], );
    $resolver->resolve(
        "$domain" => 'a',
        sub {
            httptest($dns, $domain, $_->[-1]) for @_;
        }
    );
}
sub httptest {
    my ($dns, $domain, $ip) = @_;
    my $url = "http://$domain/10k.html";
    my $begin = time;
    http_get $url, proxy => [$ip, 80], want_body_handle => 1, sub {
        my ($hdl, $hdr) = @_;
        my ($port, $peer) = AnyEvent::Socket::unpack_sockaddr getpeername $hdl->{'fh'};
        my $data = freeze( { dns => $dns, status => $hdr->{Status}, local => $local, ip => $peer, len => $hdr->{'content-length'} } );
        $redisp->publish('report', $data);
    };
}
```

这里需要单独建立两个 `$redisr` 和 `$redisp` ，因为前一个已经用来 subscribe 之后就不能同时用于 publish 了，会报错。从理解上这是个很扯淡的事情，不过实际运行结果就是如此。。。
