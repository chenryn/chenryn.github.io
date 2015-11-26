---
layout: post
title: CloudForecast学习笔记(一)
date: 2011-08-17
category: perl
---

近三天学习cloudforecast，这是一个日本SA写的分布式监控的perl项目。日本的运维水平和perl水平，都让人羡慕啊……
项目介绍：
http://blog.riywo.com/2011/02/27/043646
demo网址:
http://editnuki.info:5000/
下载地址：
https://github.com/kazeburo/cloudforecast
粗略的看了主要文件，主要是用Class::*完成的OO，Plack::MiddleWare::*完成的web，Gearman::Worker调用Data::*里的具体模块完成对服务器的监控抓取，然后调用RRDs完成监控数据图像的更新，在启动分布式的情况下，则用Gearman::Client传输监控数据给调用RRDs的worker。

第一篇主要记录一下监控数据在服务器上流程，cloudforecast是怎么去抓取数据，怎么传递给rrd的。
不过，先看看Class::*的用法：
在CloudForecast::Data中，有如下一段代码：
```perl
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/hostname address details args
                             component_config _component_instance
                             global_config/);
__PACKAGE__->mk_classdata('rrd_schema');
__PACKAGE__->mk_classdata('fetcher_func');
__PACKAGE__->mk_classdata('graph_key_list');
__PACKAGE__->mk_classdata('graph_defs');
__PACKAGE__->mk_classdata('title_func');
__PACKAGE__->mk_classdata('sysinfo_func');```
这里，先用use base()加载两个父类继承关系。然后用Class::Accessor::Fast的mk_accessors方法创建了一堆可读写的变量，这里有另一种写法，看起来更舒服一些：
```perluse Class::Accessor "moose-like";
has hostname => ( is => 'rw', isa => 'Str' );```
然后是Class::Data::Inheritable的mk_classdata方法创建了一堆可继承的方法。
在CPAN上看到另外有一个模块叫Class::Data::Accessor的，是上面这两个模块的合集，不过作者声明说已经废弃，推荐大家使用Moose了……

现在来跟踪一下fetch_worker的流程：
先看cf_fetcher_worker脚本里new一个worker出来后，执行的是fetcher_worker()；

然后看lib/CloudForecast/Gearman/Worker.pm里的fetcher_worker()，在连接上gearmand上的fetcher任务后，执行的是$self->load_resource();

然后看lib/CloudForecast/Gearman/Worker.pm里的load_resource()，其实就是根据具体监控项require并且new一个CloudFarecast::Data::*（这个new方法是通过use base和SUPER::new最终到的CloudFarecast.pm上的）。

然后看fetcher_worker()的下一句"$resource->exec_fetch;"，先去找CloudFarecast::Data::*，发现没有exec_fetch()，那往base的CloudFarecast::Data上看，果然有了。其中的主要两行"$ret = $self->do_fetch();"和"$self->call_updater($ret);"。

然后看do_fetch()。其中主要两行"my $ret = $self->fetcher_func->($self);"和"my $schema = $self->rrd_schema;"。这两个fetcher_func和rrd_schema都是前面mk_classdata出来的方法。而这里的$self，则一直追溯到最前面Worker.pm里的$resource，即CloudForecast::Data::*。

选一个CloudForecast::Data::Basic看，其中分别调用了Data.pm里的rrds/graph/title/fetcher函数。

返回Data.pm看fetcher()函数如下：
```perlsub fetcher(&) {
    my $class = caller;
    Carp::croak("already seted fetcher_func") if $class->fetcher_func;
    $class->fetcher_func(shift);
}```
学习一下，这里新出现的一个caller函数，这是perl自带的函数，可以使用perldoc -f caller查看详细说明。默认返回三个值，分别是调用的package/file/linenumber。显然这里就是获取package，也就是$class = 'CloudFarecast::Data::Basic'了。然后返回的"$class->fetcher_func(shift);"，这个shift也就是(&)里的内容，即Basic.pm里的{my $c = shift;my @map = ...;my $ret = $c->component('SNMP')->get(@map);return $ret;}这个匿名函数。
这样前面Worker里的$resource就有了自己的fetcher_func函数了，就此执行并且返回$ret。完成！

然后把$ret传递给call_updater()函数。这个函数中先对配置文件做一次判断，是否enable了gearmand。如果没有，直接调用exec_updater()完成本地rrd图像的初始化init_rrd()或更新update_rrd()。如果有，则连接上gearmand，new一个CloudForecast::Gearman对象，使用updater方法提交数据。

然后看Gearman.pm中的updater()，其实就是Gearman::Client的dispatch_background()连接上updater任务，发送数据。

