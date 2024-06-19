---
layout: post
theme:
  name: twitter
title: 用AnyEvent和ForkManager写一个http协议的压测工具
category: testing
tags:
  - perl
---
话不多说，先上第一版的代码：
```perl
use Time::HiRes qw/time/;
use AnyEvent::HTTP;
use AnyEvent;
use Coro;

my %code;
my $count = $ARGV[0];
my $url = "https://10.10.10.10/";
my $begin = time;
my @coro = map {
    async {
        my $cv = AnyEvent::condvar;
        $cv->begin;
        my $header_time;
        http_request GET => "$url",
            sub {
                my (undef, $hdr) = @_;
                $code{$hdr->{'Status'}}++;
                $cv->end;
            }
        ;
        $cv->recv;
    }
} (1 .. $count);
$_->join for @coro;
print $cpus*$ARGV[0]/(time-$begin);
```

上面这段脚本，作用是在每个进程中运行事件驱动的协程，以达到尽可能大的并发请求。

初步的测试，在单核Coro的情况下可以每秒发送1000+的https请求。

注意：如果使用的是AnyEvent::HTTP::LWP::UserAgent模块，虽然POD里写它用的其实就是AnyEvent::HTTP的代码套LWP的API格式，但实际只能用到30%的CPU，单核情况下的qps也就不到350的样子。

注意：本例测试的是HTTPS，AnyEvent::HTTP在TLS模式(即https请求)下，无法开启persistent连接。如果是普通http请求，开启persistent参数的qps应该会更高！

然后上第二版的代码，改用了EV循环，性能比Coro协程提高了大概5%的样子。使用了fork多进程，并且绑定到不同的CPU核上。
```perl
#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Parallel::ForkManager;
use Time::HiRes qw/time/;
use Sys::CpuAffinity;
use AnyEvent::HTTP;
use AE;
use EV;

my $cpus = Sys::CpuAffinity::getNumCpus();
my $pm = new Parallel::ForkManager($cpus, "/tmp/");
my @urls = qw(https://10.11.19.35/ https://10.11.21.121/);
my $res;

$pm->run_on_finish( sub {
    my $data = $_[5];
    $res->{'code'}->{$_} += $data->{'code'}->{$_} for keys %{$data->{'code'}};
    $res->{'size'} += $data->{'size'};
    $res->{'time'} += $data->{'time'};
});

my $begin = time;
foreach my $cpu (1 .. $cpus) {
    my $pid = $pm->start and next;
    Sys::CpuAffinity::setAffinity($$, 2 ** ($cpu-1));
    my $data = ae_get($ARGV[0], \@urls);
    $pm->finish(0, $data);
}
$pm->wait_all_children;
my $use = time - $begin;

printf "%d fetches, %d max processes, in %.03f seconds\n", $ARGV[0] * $cpus, $cpus, $use;
printf "%.03f fetches/sec, %.03f bytes/sec\n", $ARGV[0] * $cpus / $use, $res->{'size'} / $res->{'time'};
printf "HTTP response codes:\n";
printf "       %d - %d\n", $_, $res->{'code'}->{$_} for sort keys %{$res->{'code'}};

sub ae_get {
    my ($count, $urls) = @_;
    my $data;
    my $tmptime;
    my $cv = AE::cv;
    for (1 .. $count) {
        my $hdr_time;
        my $url = $urls->[int(rand($#{$urls}+1))];
        $cv->begin;
        http_request
            GET       => "$url", 
            on_header => sub {
                $hdr_time = time;
            },
            sub {
                my (undef, $hdr) = @_;
                $data->{'code'}->{$hdr->{'Status'}}++;
                $data->{'size'} += $hdr->{'content-length'};
                $data->{'time'} += ( time - $hdr_time );
                $cv->end;
            }
        ;
    } 
    $cv->recv;
    return $data;
}
```

增加了简单的统计功能，包括每秒请求数、平均下载速度，状态码汇总等。因为不好计算header的长度，所以只计算body部分的下载速度。
增加了url列表功能，每次请求会随机的抽取其中的一个url。
