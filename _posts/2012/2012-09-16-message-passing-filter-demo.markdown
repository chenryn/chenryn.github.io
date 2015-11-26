---
layout: post
title: 【Message::Passing系列】过滤器实例
category: logstash
tags:
  - perl
  - message-passing
---

[Message::Passing](http://github.com/suretec)是Suretec公司为自己的VoIP业务开发的logstash山寨版。这几个月更新还是比较快的。比之前我刚关注它时改变很大。比如Message::Passing::Output::ElasticSearch已经出来了，还有专门的Message::Passing::Filter::ToLogstash，连命令行方式Message::Passing::Role::Script都采用了MooX::Options构建，相当的OO了。

不过可能是运用环境的区别吧，作者一直在filter方面没有什么动静，可怜巴巴的null/all/key/tologstash这么几个，比起input和output的列表差太远了。而且像logstash里的jls-grok这么最有力的工具没有山寨。

今天有空，稍微写了个例子，可以比较方便的定义类似grok_pattern的方式完成对accesslog的json序列化。不过配置方式比Grok还是麻烦不少，以后真用的话，再考虑config的办法吧，这里主要是为了展示Message::Passing::Filter::XXX的编写：

```perl
    #!/usr/bin/perl
    package Message::Passing::Filter::GrokLike;
    use Moo;
    use MooX::Types::MooseLike::Base qw/ ArrayRef Str /;
    use List::MoreUtils qw/ uniq /;
    use DateTime;
    use Regexp::Log::Nginx;
    use namespace::clean -except => 'meta';
    with 'Message::Passing::Role::Filter';
    has format => (
        is => 'ro',
        isa => Str,
        default => sub { '%date %status %remotehost %domain %request %originhost %responsetime %upstreamtime %bytes %referer %useragent %xforwarderfor' },
    );
    has capture => (
        is => 'ro',
        isa => ArrayRef,
        default => sub { [ 'ts', 'status', 'remotehost', 'url', 'oh', 'responsetime', 'upstreamtime', 'bytes' ] },
    );
    has _grok => (
        is => 'ro',
        lazy => 1,
        builder => '_build_grok',
    );
    sub _build_grok {
        my $self = shift;
        my $rln = Regexp::Log::Nginx->new(
            format  => $self->format,
            capture => $self->capture,
        );
        return $rln;
    };
    sub filter {
        my ($self, $message) = @_;
        my @fields = $self->_grok->capture;
        my $re = $self->_grok->regexp;
        my %data;
        @data{@fields} = $message->{'@message'} =~ m/$re/;
        $message->{'@fields'} = {
            %data,
            responsetime => $data{'responsetime'} + 0,
            upstreamtime => $data{'upstreamtime'} + 0,
            bytes        => $data{'bytes'}        + 0,
        };
        $message;
    };
    true;
```

--------------

__2012 年 12 月 30 日附注：__

前两天已经把这个模块正规化后上传到 CPAN 上了。把捕获定义成 `.ini` 文件，同时还加入了类似 logstash 里的 mutate filter 的功能。模块叫 `Message::Passing::Filter::Regexp`。同时上传了一个 `Message::Passing::Output::PocketIO` 模块，可以打开一个网页时时接收output。
