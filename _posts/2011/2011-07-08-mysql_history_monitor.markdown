---
layout: post
title: mysql_history_monitor
date: 2011-07-08
category: monitor
tags:
  - MySQL
---

上篇加了bash_history的监控，这篇说mysql_history的监控。不像bash4，mysql自始至终没有提供过syslog的代码，只能自己通过守护进程去实时获取~/.mysql_history的记录了。一个小脚本如下：
{% highlight perl %}#!/usr/bin/perl -w
use POE qw(Wheel::FollowTail);
use Log::Syslog::Fast qw(:all);

defined(my $pid = fork) or die "Cant fork:$!";
unless($pid){  
}else{
         exit 0;
}

POE::Session->create(
    inline_states => {
      _start => sub {
        $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
          Filename => "/root/.mysql_history",
          InputEvent => "got_log_line",
          ResetEvent => "got_log_rollover",
        );
      },
      got_log_line => sub {
#通过Data::Dumper看到实际是$_[10]，不过在POE::Session里定义了sub ARG0 () { 10 };这样写起来简单了
        to_rsyslog($_[ARG0]);
      },
      got_log_rollover => sub {
        to_rsyslog('roll');
      },
    }
);

POE::Kernel->run();
exit;

sub to_rsyslog {
  $message = join' ',@_;
#rsyslog开的是UDP的514端口；而LOG_LOCAL0和LOG_INFO都是syslog定义的，乱写的话会自动归入kernel | alert
  my $logger = Log::Syslog::Fast->new(LOG_UDP, "10.0.0.123", 514, LOG_LOCAL0, LOG_INFO, "mysql_231", "mysql_monitor");
  $logger->send($message ,time);
};{% endhighlight %}

当然，mysql的history其实不止一个位置，需要判断~
