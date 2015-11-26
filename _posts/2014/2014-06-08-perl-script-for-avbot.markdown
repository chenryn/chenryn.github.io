---
layout: post
title: 配合 avbot 的 HTTP 接口做自动应答的 Perl 脚本
category: perl
tags:
  - anyevent
  - devops
---

前两天[博客里介绍了 avbot](http://chenlinux.com/2014/06/04/record-webqq-logs-by-avbot)，其中提到 avbot 提供了 HTTP 接口可以收发信息。那么，我们就可以自己写脚本来实现比原先的 `.qqbot help` 更详细的自动应答啦。今晚有空就写了几行 Perl ，实现了一个简单的扩展：

```perl
use utf8;
use strict;
use warnings;
use JSON::XS;
use AnyEvent;
use AnyEvent::HTTP;

my $f = {
    help => ".logstashbot support subcommand:\n\t",
    grok => '请主动使用 http://grokdebug.herokuapp.com',
    tnnd => '请直接说问题不要浪费口水问有人帮忙么',
    book => '支持原作者，请购买 www.logstashbook.com 上电子版',
};
$f->{'help'} .= join("\n\t", keys %$f);

$AnyEvent::HTTP::TIMEOUT = 86400;
my $url = 'http://127.0.0.1:6176/message';
my $cv = AnyEvent->condvar;

my $ua;$ua = sub {
    $cv->begin;
    http_get $url, sub {
        my ($data, $header) = @_;
        my $hash = decode_json $data;
        my $msg = $hash->{'message'}{'text'};
        my $from = '@' . $hash->{'who'}{'nick'} . '(' . $hash->{'who'}{'code'} . ")\n";
        if ( $msg =~ /^\.logstashbot (\w+)/ ) {
            my $body = encode_json({
                protocol => delete $hash->{'protocol'},
                channel  => delete $hash->{'channel'},
                message  => {
                    text => $from . ( $f->{$1} // $f->{'help'} ),
                },
            });
            $cv->begin;
            http_post $url, $body, sub {
                $cv->end;
            };
        };
        $ua->();
        $cv->end;
    };
};
$ua->();

$cv->recv;
```

原先是打算在回调里 `undef $ua` 然后通过 `AnyEvent->timer` 里检测 $ua 是否还在，否则再起来的方式。后来一想 `timer` 还有间隔，直接函数内部通过 `$cv->end` 控制计数，不断的重新运行 `$ua->()` 来保持持续获取，间隔更短，就改成现在这样了。
