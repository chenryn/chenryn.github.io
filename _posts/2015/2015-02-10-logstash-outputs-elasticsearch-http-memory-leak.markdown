---
layout: post
theme:
  name: twitter
title: LogStash::Outputs::ElaticSearch 使用 http 协议时的内存泄露问题
category: logstash
tags:
  - ruby
  - elasticsearch
---

Logstash 早年有三种不同的插件写数据到 Elasticsearch 中，分别采用 node，http 和 river 方式。从 1.4 版本以后，在重构的 LogStash::Outputs::ElasticSearch 插件中，通过 `protocol` 参数，完成了对多种方式的整合。其中，node 和 transport 方式，都是调用 Java 库的 API，而 http 方式，则调用的 REST API。

在 Elasticsearch 集群和 Logstash 集群不在一个网段的时候，一般都只能采用 REST API 写数据。而且根据测试情况，采用 http 方式的写入性能，也要稍微高过 node 方式，所以，我一直都推荐采用这种方式。不过随着系统的长期运行，却发现日志流转总是不太顺畅，实际写入 Elasticsearch 的数据慢慢的就会越来越少。因为 Logstash 本身内部并无缓存机制，所以比较难判断到底是哪步出了问题——甚至可能就是 Elasticsearch 在高负载情况下就写不动？

和 childe 聊了一下携程采用 transport 方式运行的情况，发现他们的 Elasticsearch 集群没有出现过类似越写越少的情况。把 logstash 的配置改成写文件，也一直没有再出现堵塞消息队列的情况。问题就此锁定在 logstash 写数据的 http 过程中。

进到源码目录里阅读[相关代码](https://github.com/elasticsearch/logstash/blob/1.4/lib/logstash/outputs/elasticsearch/protocol.rb#L67)，发现在 `build_client` 方法里有很有趣的一段注释：

> # Use FTW to do indexing requests, for now, until we
> # can identify and resolve performance problems of elasticsearch-ruby

这个好玩了。因为我在两年前用过官方出的 elasticsearch 的 Perl 客户端库，性能是非常不错的。怎么 Ruby 库会这么被嫌弃？

于是又切换到当前最新的 1.5.0beta1 版本看看这块是[怎么处理的](https://github.com/logstash-plugins/logstash-output-elasticsearch/blob/master/lib/logstash/outputs/elasticsearch/protocol.rb#L70)。最新版已经放弃了作者自己的 FTW 库，用上了官方的 Ruby 库，具体传输层用的是 JRuby 专有的 Manticore 库。

然后又发现 github 上几个相关的 issue：

* [File descriptors are leaked when using HTTP](https://github.com/elasticsearch/logstash/issues/1604)
* [Add HTTP Auth and SSL to the ES output plugin](https://github.com/elasticsearch/logstash/pull/1777)
* [manticore wiki/Performance](https://github.com/cheald/manticore/wiki/Performance)

所以问题很明确了，logstash-1.4.2 依赖的 ftw-0.0.39，有内存泄露问题。logstash 开发者在去年十一月升级了 ftw-0.0.40 解决这个问题，但是 logstash-1.4 那时候已经没有 release 计划了…… 差不多同时间，LogStash::Outputs::ElasticSearch 更换了底层 HTTP 依赖库为性能跟 FTW 相近的 Manticore，并且在前些天随 1.5.0beta1 版本发布。

升级成 1.5.0beta1 后，测试运行几天，Elasticsearch 的写入数据量一直没有下降。可以认定问题解决。

Logstash-1.5 和 Logstash-1.4 在 plugin API 方面没有什么变化，有写自己 plugin 的童鞋不用太过担心，可以放心测试然后升级使用。我目前发现的唯一一个变化就是：Logstash-1.5 改用 jackson 库替代原生 json 库了。所以原先可以直接：

```ruby
    parsed = JSON.parse(msg)
```

现在应该通过 logstash 内部方式调用：

```ruby
    require 'logstash/json'
    parsed = LogStash::Json.load(msg)
```

