---
layout: post
title: 【Message::Passing系列】Regexp::Log模板匹配变量
category: logstash
tags:
  - perl
  - message-passing
---

上面调用的Regexp::Log::Nginx是base Regexp::Log的实例，CPAN上已经提供了好些server的log regex，见<http://search.cpan.org/search?query=Regexp%3A%3Alog&mode=all>。
{% highlight perl %}
    #!/usr/bin/perl
    package Regexp::Log::Nginx;
    use warnings;
    use strict;
    use base qw( Regexp::Log );
    use vars qw( $VERSION %DEFAULT %FORMAT %REGEXP );
    %DEFAULT = (
            format  => '%date %status %remotehost %domain %request %originhost %responsetime %upstreamtime %bytes %referer %useragent %xforwarderfor',
            capture => [ 'ts', 'status', 'remotehost', 'url', 'oh', 'responsetime', 'upstreamtime', 'bytes' ],
    );
    %FORMAT = (
            ':default' => '%date %status %remotehost %domain %request %originhost %responsetime %upstreamtime %bytes %referer %useragent %xforwarderfor',
    );
    %REGEXP = (
            '%date' => '(?#=date)\[(?#=ts)\d{2}\/\w{3}\/\d{4}(?::\d{2}){3}(?#!ts) [-+]\d{4}\](?#!date)',
            '%status' => '(?#=status)\d+(?#!status)',
            '%remotehost' => '(?#=remotehost)\S+(?#!remotehost)',
            '%domain' => '(?#=domain).*?(?#!domain)',
            '%request' => '(?#=request)-|(?#=method)\w+(?#!method) (?#=url).*?(?#!url) (?#=version)HTTP/\d\.\d(?#!version)(?#!request)',
            '%originhost' => '(?#=originhost)-|(?#=oh).*?(?#!oh):\d+(?#!originhost)',
            '%responsetime' => '(?#=responsetime)-|.*?(?#!responsetime)',
            '%upstreamtime' => '(?#=upstreamtime).*?(?#!upstreamtime)',
            '%bytes' => '(?#=bytes)\d+(?#!bytes)',
            '%referer' => '(?#=referer)\"(?#=ref).*?(?#!ref)\"(?#!referer)',
            '%useragent' => '(?#=useragent)\"(?#=ua).*?(?#!ua)\"(?#!useragent)',
            '%xforwarderfor' => '(?#=xforwarderfor)\"(?#=xff).*?(?#!xff)\"(?#!xforwarderfor)',
    );
    1;
{% endhighlight %}

