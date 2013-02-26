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
听起来似乎不是什么问题，我个人之前对nagios的追求，也都放在怎么样提供一个及时高效的监控和数据展示上面----这两个问题在mod_gearman和pnp4nagios的协助下已经很给力了。    
但是聊天中提到了一个新的场景，事实上早在两个月前，[@GNUer](http://weibo.com/tjpm) 就提到过类似的场景，就是当nagios监控的是这样一个弹性集群的时候：

    集群设备数以千记，甚至是上万的规模；
    而且设备上运行着复杂的应用，每台设备都有几十上百的监控项需求；
    为了提供高可靠性，集群以资源池的方式运行，即设备随时可能更改当前应用角色，在idle/lb/cache/web/app/db/storage等之间切换；

以上。    
尤其是最后一条，假如这个更改频率快到了每分钟都有变更，那么nagios重启进程这点就足以打死它了。实际运行中我们可以知道，当nagios reload的时候，这个命令的执行本身就要花费远大于1分钟的时间。    
临时的办法，就是在更改后不主动reload，而是在crond里定时去做。损失一些监控实时性。一般来说，还不至于真的同一台设备一分钟内连续更改角色并且需要分别监控的。    

但是真要做到实时，应该怎么做呢？    

首先想到的是mod_gearman的基础上进行改造。我们之前已经知道，mod_gearman上是可以分别有host_check/service_check/check_result几个jobs的。那么，我们可以跳过config阶段，自己写gearman client发送job。这一步很容易。难点是check_result被nagios回收后，我们自己发的job，其host/service在nagios的service_list结构里是不存在的......所以还要自己写gearman worker来回收result，具体来说，必须要做的事情包括有：根据performance_data来create和update相应的rrds；根据exit status来启动notification。这个工作内容一下子达到自己重写一个比较完整的监控系统的地步了，而且你如果通过原版的cgi查看，这部分内容还查看不到......    

于是我在github上询问mod_gearman的作者[Sven Nierlein](https://github.com/sni) ，他回答说：

    There is no such feature right now and it would be very hard to implement such thing in nagios or icinga.
    It should be easier to implement something like that in shinken, but i guess it still takes 2-3 weeks of development.

好吧，比较失望的回答。尝试去瞄一眼nagios-src，在base/events.c里可以看到，nagios是在读取完全部config之后，才进入loop，并提供eventbroker的api的。    
shinken是完全重写过的披着nagios皮的监控系统，在[shinken的suggestion征集页面](http://shinken.ideascale.com/) 上，我看到也有一位提议：[Arbiter configuration without reloading daemon](http://shinken.ideascale.com/a/dtd/Arbiter-configuration-without-reloading-daemon/323455-10373)，不过应者寥寥，看来这种需求真的是极少数人才会碰到的。    
既然说到用gearman，又说到监控，再回头看看去年提到的cloudforecast。在ConfigLoader.pm中，可以看到一个watchdog方法。具体代码如下：

{% highlight perl %}
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
{% endhighlight %}

可以看到，其实现方法是通过另起进程，通过inotify监听文件修改的方式，"实时"的重启主进程。实质上与nagios并无区别，都是要重新加载内存中保存的整个监控项配置列表。虽然没有大压力运用，但是可以猜测在预设环境中，重启耗时也会是瓶颈。    

另外一个监控系统zabbix，与上面两个系统都不同，他的监控配置，不是通过文件方式存在监控服务器上，而是通过web操作保存在数据库里。整个host/item/template等等都是鼠标点击即可。    
zabbix我的使用经验不多，只在三年前用它的预设步骤的方式监控过网页性能。印象中在create graph后需要等待一定时间后才能反映出结果。但不确定这个时间是监控项排队消耗的，还是监控进程重启消耗掉的。    
和[@超大杯摩卡星冰乐](http://weibo.com/frankymryao) 询问了一下，只能猜测或许是通过循环scan table的方式"实时"的添加"新"监控项到监控进程的队列里。或许也得跟分析nagios一样看看代码才知道是否能在本文预设的弹性环境下适用了。

至于ganglia，彻底米用过，暂时就不讨论了。

