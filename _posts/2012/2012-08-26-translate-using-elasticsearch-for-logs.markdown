---
layout: post
title: 【翻译】用ElasticSearch存储日志
category: logstash
tags:
  - elasticsearch
---

# 介绍

如果你使用elasticsearch来存储你的日志，本文给你提供一些做法和建议。

如果你想从多台主机向elasticsearch汇集日志，你有以下多种选择：

- [Graylog2](http://graylog2.org/) 安装在一台中心机上，然后它负责往elasticsearch插入日志，而且你可以使用它那个漂亮的搜索界面~
- [Logstash](http://logstash.net/) 他有很多特性，包括你能输入什么日志，如何变换过滤，最好输出到哪里。其中就有输出到elasticsearch，包括直接输出和通过[RabbitMQ的river](http://www.elasticsearch.org/guide/reference/river/rabbitmq.html)方式两种。
- [Apache Flume](https://cwiki.apache.org/FLUME/) 这个也可以从海量数据源中获取日志，用"decorators"修改日志，也有各种各样的"sinks"来存储你的输出。和我们相关的是[elasticflume sink](https://github.com/Aconex/elasticflume)。
- omelasticsearch Rsyslog的输出模块。你可以在你的应用服务器上通过rsyslog直接输出到elasticsearch，也可以用rsyslog传输到中心服务器上来插入日志。或者，两者结合都行。具体如何设置参见[rsyslog Wiki](http://wiki.rsyslog.com/index.php/HOWTO:_rsyslog_%2B_elasticsearch)。
- 定制方案。比如，专门写一个脚本从天南海北的某个服务器传输你的日志到elasticsearch。

根据你设定的不同，最佳配置也变化不定。不过总有那么几个有用的指南可以推荐一下：

## 内存和打开的文件数

如果你的elasticsearch运行在专用服务器上，经验值是分配一半内存给elasticsearch。另一半用于系统缓存，这东西也很重要的。

你可以通过修改ES_HEAP_SIZE环境变量来改变这个设定。在启动elasticsearch之前把这个变量改到你的预期值。另一个选择上球该elasticsearch的ES_JAVA_OPTS变量，这个变量时在启动脚本(elasticsearch.in.sh或elasticsearch.bat)里传递的。你必须找到-Xms和-Xmx参数，他们是分配给进程的最小和最大内存。建议设置成相同大小。嗯，ES_HEAP_SIZE其实就是干的这个作用。

你必须确认文件描述符限制对你的elasticsearch足够大，建议值是32000到64000之间。关于这个限制的设置，另有[教程](http://www.elasticsearch.org/tutorials/2011/04/06/too-many-open-files.html)可以参见。

## 目录数

一个可选的做法是把所有日志存在一个索引里，然后用[ttl field](http://www.elasticsearch.org/guide/reference/mapping/ttl-field.html)来确保就日志被删除掉了。不过当你日志量够大的时候，这可能就是一个问题了，因为用TTL会增加开销，优化这个巨大且唯一的索引需要太长的时间，而且这些操作都是资源密集型的。

建议的办法是基于时间做目录。比如，目录名可以是YYYY-MM-DD的时间格式。时间间隔完全取决于你打算保留多久日志。如果你要保留一周，那一天一个目录就很不错。如果你要保留一年，那一个月一个目录可能更好点。目录不要太多，因为全文搜索的时候开销相应的也会变大。

如果你选择了根据时间存储你的目录，你也可以缩小你的搜索范围到相关的目录上。比如，如果你的大多数搜索都是关于最近的日志的，那么你可以在自己的界面上提供一个"快速搜索"的选项只检索最近的目录。

## 轮转和优化

移除旧日志在有基于时间的目录后变得异常简单：
{% highlight bash %}
$ curl -XDELETE 'http://localhost:9200/old-index-name/'
{% endhighlight %}
这个操作的速度非常快，和删除大小差不多的少量文件速度接近。你可以放进crontab里半夜来做。

[Optimizing indices](http://www.elasticsearch.org/guide/reference/api/admin-indices-optimize.html)是在非高峰时间可以做的一件很不错的事情。因为它可以提高你的搜索速度。尤其是在你是基于时间做目录的情况下，更建议去做了。因为除了当前的目录外，其他都不会再改，你只需要对这些旧目录优化一次就一劳永逸了。
{% highlight bash %}
$ curl -XPOST 'http://localhost:9200/old-index-name/_optimize'
{% endhighlight %}

## 分片和复制

通过elasticsearch.yml或者使用REST API，你可以给每个目录配置自己的设定。具体细节参见[链接](http://www.elasticsearch.org/guide/reference/setup/configuration.html)。

有趣的是分片和复制的数量。默认情况下，每个目录都被分割成5个分片。如果集群中有一个以上节点存在，每个分片会有一个复制。也就是说每个目录有一共10个分片。当往集群里添加新节点的时候，分片会自动均衡。所以如果你有一个默认目录和11台服务器在集群里的时候，其中一台会不存储任何数据。

每个分片都是一个Lucene索引，所以分片越小，elasticsearch能放进分片新数据越少。如果你把目录分割成更多的分片，插入速度更快。请注意如果你用的是基于时间的目录，你只在当前目录里插入日志，其他旧目录是不会被改变的。

太多的分片带来一定的困难——在空间使用率和搜索时间方面。所以你要找到一个平衡点，你的插入量、搜索频率和使用的硬件条件。

另一方面，复制帮助你的集群在部分节点宕机的时候依然可以运行。复制越多，必须在线运行的节点数就可以越小。复制在搜索的时候也有用——更多的复制带来更快的搜索，同时却增加创建索引的时间。因为对猪分片的修改，需要传递到更多的复制。

## 映射_source和_all

[Mappings](http://www.elasticsearch.org/guide/reference/mapping/)定义了你的文档如何被索引和存储。你可以，比如说，定义每个字段的类型——比如你的syslog里，消息肯定是字符串，严重性可以是整数。怎么定义映射参见[链接](http://www.elasticsearch.org/guide/reference/api/admin-indices-put-mapping.html)。

映射有着合理的默认值，字段的类型会在新目录的第一条文档插入的时候被自动的检测出来。不过你或许会想自己来调控这点。比如，可能新目录的第一条记录的message字段里只有一个数字，于是被检测为长整型。当接下来99%的日志里肯定都是字符串型的，这样Elasticsearch就没法索引他们，只会记录一个错误日志说字段类型不对。这时候就需要显式的手动映射"message" : {"type" : "string"}。如何注册一个特殊的映射详见[链接](http://www.elasticsearch.org/guide/reference/api/admin-indices-put-mapping.html)。

当你使用基于时间的目录名时，在配置文件里创建索引模板可能更适合一点。详见[链接](http://www.elasticsearch.org/guide/reference/api/admin-indices-templates.html)。除去你的映射，你海可以定义其他目录属性，比如分片数等等。

在映射中，你可以选择压缩文档的_source。这实际上就是整行日志——所以开启压缩可以减小索引大小，而且依赖你的设定，提高性能。经验值是当你被内存大小和磁盘速度限制的时候，压缩源文件可以明显提高速度，相反的，如果受限的是CPU计算能力就不行了。更多关于source字段的细节详见[链接](http://www.elasticsearch.org/guide/reference/mapping/source-field.html)。

默认情况下，除了给你所有的字段分别创建索引，elasticsearch还会把他们一起放进一个叫_all的新字段里做索引。好处是你可以在_all里搜索那些你不在乎在哪个字段找到的东西。另一面是在创建索引和增大索引大小的时候会使用额外更多的CPU。所以如果你不用这个特性的话，关掉它。即使你用，最好也考虑一下定义清楚限定哪些字段包含进_all里。详见[链接](http://www.elasticsearch.org/guide/reference/mapping/all-field.html)。

## 刷新间隔

在文档被索引后，Elasticsearch某种意义上是近乎实时的。在你搜索查找文档之前，索引必须被刷新。默认情况下，目录是每秒钟自动异步刷新的。

刷新是一个非常昂贵的操作，所以如果你稍微增大一些这个值，你会看到非常明显提高的插入速率。具体增大多少取决于你的用户可以接受到什么程度。

你可以在你的[index template](http://www.elasticsearch.org/guide/reference/api/admin-indices-templates.html)里保存期望的刷新间隔值。或者保存在elasticsearch.yml配置文件里，或者通过(REST API)[http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html]升级索引设定。

另一个处理办法是禁用掉自动刷新，办法是设为-1。然后用[REST API](http://www.elasticsearch.org/guide/reference/api/admin-indices-refresh.html)手动的刷新。当你要一口气插入海量日志的时候非常有效。不过通常情况下，你一般会采用的就是两个办法：在每次bulk插入后刷新或者在每次搜索前刷新。这都会推迟他们自己本身的操作响应。

## Thrift

通常时，REST接口是通过HTTP协议的，不过你可以用更快的Thrift替代它。你需要安装[transport-thrift plugin](https://github.com/elasticsearch/elasticsearch-transport-thrift)同时保证客户端支持这点。比如，如果你用的是[pyes Python client](https://github.com/aparo/pyes)，只需要把连接端口从默认支持HTTP的9200改到默认支持Thrift的9500就好了。

## 异步复制

通常，一个索引操作会在所有分片(包括复制的)都完成对文档的索引后才返回。你可以通过[index API](http://www.elasticsearch.org/guide/reference/api/index_.html)设置复制为异步的来让复制操作在后台运行。你可以直接使用这个API，也可以使用现成的客户端(比如pyes或者rsyslog的omelasticsearch)，都会支持这个。

## 用过滤器替代请求

通常，当你搜索日志的时候，你感兴趣的是通过时间序列做排序而不是评分。这种使用场景下评分是很无关紧要的功能。所以用过滤器来查找日志比用请求更适宜。因为过滤器里不会执行评分而且可以被自动缓存。两者的更多细节参见[链接](http://www.elasticsearch.org/guide/reference/query-dsl/)。

## 批量索引

建议使用[bulk API](http://www.elasticsearch.org/guide/reference/api/bulk.html)来创建索引它比你一次给一条日志创建一次索引快多了。

主要要考虑两个事情：

- 最佳的批量大小。它取决于很多你的设定。如果要说起始值的话，可以参考一下pyes里的默认值，即400。
- 给批量操作设定时器。如果你添加日志到缓冲，然后等待它的大小触发限制以启动批量插入，千万确定还要有一个超时限制作为大小限制的补充。否则，如果你的日志量不大的话，你可能看到从日志发布到出现在elasticsearch里有一个巨大的延时。

