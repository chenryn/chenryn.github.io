---
layout: post
title: 弹性集群监控中的配置自动生效问题研究
date: 2012-04-16
category: monitor
tags:
  - nagios
  - gearman
  - perl
---

最近跟[@画圈圈的星星](http://weibo.com/fedoracore) 聊天，说到nagios在大规模集群运用中一个比较严重的瓶颈：修改配置需要重启进程。   
听起来似乎不是什么问题，我个人之前对nagios的追求，也都放在怎么样提供一个及时高效的监控和数据展示上面----这两个问题在 `mod_gearman` 和 `pnp4nagios` 的协助下已经很给力了。    

但是聊天中提到了一个新的场景，事实上早在两个月前，[@GNUer](http://weibo.com/tjpm) 就提到过类似的场景，就是当 nagios 监控的是这样一个弹性集群的时候：

    集群设备数以千记，甚至是上万的规模；
    而且设备上运行着复杂的应用，每台设备都有几十上百的监控项需求；
    为了提供高可靠性，集群以资源池的方式运行，即设备随时可能更改当前应用角色，在idle/lb/cache/web/app/db/storage等之间切换；

以上。    

尤其是最后一条，假如这个更改频率快到了每分钟都有变更，那么 nagios 重启进程这点就足以打死它了。实际运行中我们可以知道，当 `nagios reload` 的时候，这个命令的执行本身就要花费远大于1分钟的时间。    

临时的办法，就是在更改后不主动 reload，而是在 crontab 里定时去做。损失一些监控实时性。一般来说，还不至于真的同一台设备一分钟内连续更改角色并且需要分别监控的。    

但是真要做到实时，应该怎么做呢？    

首先想到的是 `mod_gearman` 的基础上进行改造。我们之前已经知道，`mod_gearman` 上是可以分别有 host_check/service_check/check_result 几个 jobs 的。那么，我们可以跳过 config 阶段，自己写 gearman client 发送 job 。这一步很容易。难点是 check_result 被 nagios 回收后，我们自己发的 job，其 host/service 在 nagios 的 service_list 结构里是不存在的......所以还要自己写 gearman worker 来回收 result，具体来说，必须要做的事情包括有：根据 performance_data 来 create 和 update 相应的 rrds；根据 exit status 来启动 notification。这个工作内容一下子达到自己重写一个比较完整的监控系统的地步了，而且你如果通过原版的 cgi 查看，这部分内容还查看不到......    

于是我在 github 上询问 `mod_gearman` 的作者[Sven Nierlein](https://github.com/sni) ，他回答说：

    There is no such feature right now and it would be very hard to implement such thing in nagios or icinga.
    It should be easier to implement something like that in shinken, but i guess it still takes 2-3 weeks of development.

好吧，比较失望的回答。尝试去瞄一眼 nagios-src，在 base/events.c 里可以看到，nagios 是在读取完全部 config 之后，才进入 loop，并提供 eventbroker 的 api 的。    

shinken 是完全重写过的披着 nagios 皮的监控系统，在 [shinken 的 suggestion 征集页面](http://shinken.ideascale.com/) 上，我看到也有一位提议：[Arbiter configuration without reloading daemon](http://shinken.ideascale.com/a/dtd/Arbiter-configuration-without-reloading-daemon/323455-10373)，不过应者寥寥，看来这种需求真的是极少数人才会碰到的。    

既然说到用 gearman，又说到监控，再回头看看去年提到的 cloudforecast。在 `ConfigLoader.pm` 中，可以看到一个 `watchdog` 方法。具体代码如下：

```perl
    my $watcher = Filesys::Notify::Simple->new(\@path);
    while (1) {
        $watcher->wait( sub {
            my @path = grep { $_ !~ m![/\\][\._]|\.bak$|~$!  } map { $_->{path} } @_;
            return if ! @path;
            CloudForecast::Log->warn( "File updates: " . join(",", @path) );
            sleep 1;
            kill 'TERM', $parent_pid;
            exit;
        } );
    }
```

可以看到，其实现方法是通过另起进程，通过 inotify 监听文件修改的方式，"实时"的重启主进程。实质上与 nagios 并无区别，都是要重新加载内存中保存的整个监控项配置列表。虽然没有大压力运用，但是可以猜测在预设环境中，重启耗时也会是瓶颈。    

另外一个监控系统 zabbix，与上面两个系统都不同，他的监控配置，不是通过文件方式存在监控服务器上，而是通过 web 操作保存在数据库里。整个 host/item/template 等等都是鼠标点击即可。    

zabbix 我的使用经验不多，只在三年前用它的预设步骤的方式监控过网页性能。印象中在 create graph 后需要等待一定时间后才能反映出结果。但不确定这个时间是监控项排队消耗的，还是监控进程重启消耗掉的。    

和[@超大杯摩卡星冰乐](http://weibo.com/frankymryao) 询问了一下，只能猜测或许是通过循环 scan table 的方式"实时"的添加"新"监控项到监控进程的队列里。或许也得跟分析 nagios 一样看看代码才知道是否能在本文预设的弹性环境下适用了。

