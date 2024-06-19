---
layout: post
theme:
  name: twitter
title: 【翻译】用 elasticsearch 和 logstash 为数十亿次客户搜索提供服务
category: logstash
tags:
  - elasticsearch
---

原文地址：<http://www.elasticsearch.org/blog/using-elasticsearch-and-logstash-to-serve-billions-of-searchable-events-for-customers/>

--------------------------------------------------

_今天非常高兴的欢迎我们的第一个外来博主，Rackspace软件开发工程师，目前为Mailgun工作的 [Ralph Meijer](https://twitter.com/ralphm)。我们在 [Monitorama EU](http://monitorama.eu/) 会面后，Ralph 提出可以给我们写一篇 Mailgun 里如何使用 Elasticsearch 的文章。他本人也早就活跃在 Elasticsearch 社区，经常参加我们在荷兰的聚会了。_

![](http://www.elasticsearch.org/content/uploads/2013/09/mailgun_150-300x85.png)

[Mailgun](http://www.mailgun.com/) 收发大量电子邮件，我们跟踪和存储每封邮件发生的每个事件。每个月会新增数十亿事件，我们都要展示给我们的客户，方便他们很容易的分析数据，也就是全文搜索。下文是我们利用Elasticsearch和Logstash技术完成这个需求的技术细节（很高兴刚写完这篇文章就听说《[Logstash加入Elasticsearch](http://elasticsearch.com/blog/welcome-jordan-logstash/)》了）。

事件
============

在 Mailgun 里，event可能是如下几种：进来一条信息，可能被接收可能被拒绝；出去一条信息，可能被投递可能被拒绝(垃圾信息或者反弹)；信息是直接打开还是通过链接点击打开；收件人要求退订。所有这些事件，都有一些元信息可以帮助我们客户找出他们的信息什么时候，为什么，发生了什么。这个元信息包括：信息的发送者，收件人地址，信息id，SMTP错误码，链接URL，geo地理位置等等。

每个事件都是由一个时间戳和一系列字段构成的。一个典型的事件就是一个关联数组，或者叫字典、哈希表。

事件访问设计
============

假设我们已经有了各种事件，现在需要一个办法来给客户使用。在Mailgun的控制面板里，有一个日志标签，可以以时间倒序展示事件日志，并且还可以通过域名和级别来过滤日志，示例如下：

![](http://9791b61a81187466cf77-03e2fb40b56101ddc8886446c68cb0c1.r77.cf2.rackcdn.com/mailgun_log_sample.png)

在这个示例里，这个事件的级别是"warn"，因为SMTP错误码说明这是一个临时性问题，我们稍后会重试投递。这里有两个字段，一个时间戳，一个还没格式化的非结构化文本信息。为了醒目，这里我们会根据级别的不同给事件上不同的底色。

在这个网页之后，我还有一个接收日志的API，一个设置触发报警的hook页面。后面的报警完全是结构化了的带有很多元数据字段的JSON文档。比如，SMTP错误码有自己的字段，收件人地址和邮件标题等也都有。

不幸的是，原有的日志API非常有限。他只能返回邮件投递时间和控制面板里展示的非结构化的文本内容。没办法获取或者搜索多个字段(像报警页面里那样)，更不要说全文搜索了。简单说，就是控制面板缺乏全文搜索。

用elasticsearch存储和响应请求
============

要给控制面板提供API和访问，我们需要一个新的后端来弥补前面提到的短板，包括下面几个新需求：

* 允许大多数属性的过滤。
* 允许全文搜索。
* 支持存储至少30天数据，可以有限度的轮滚。
* 添加节点即可轻松扩展。
* 节点失效无影响。

而Elasticsearch，是一个可以“准”实时入库、实时请求的搜索引擎。它基于Apache Lucene，由存储索引的节点组成一个分布式高可用的集群。单个节点离线，集群会自动把索引(的分片)均衡到剩余节点上。你可以配置具体每个索引有多少分片，以及这些分片该有多少副本。如果一个主分片离线，就从副本中选一个出来提升为主分片。

Elasticsearch 是面向文档的，某种层度上可以说也是无模式的。这意味着你可以传递任意JSON文档然后就可以索引成字段。对我们的事件来说完全符合要求。

Elasticsearch 同样还有一个非常强大的请求/过滤接口，可以对特定字段搜索，也可以做全文搜索。

事件存入elasticsearch
============

有很多工具或者服务可以用来记录事件。我们最终选择了 [Logstash](http://logstash.net/)，一个搜集、分析、管理和传输日志的工具。

在内部，通过webhooks推送来的event同时在我们系统的其他部分也有使用，目前我们是用Redis来完成这个功能。Logstash有一个Redis输入插件来从Redis列表里接收日志事件。通过几个小过滤器后，事件通过一个输出插件输出。最常用的输出插件就是 Elasticsearch 插件。

利用 Elasticsearch 丰富的 API 最好的办法就是使用 Kibana，这个工具的口号是“让海量日志有意义”。目前最新的 [Kibana 3](http://three.kibana.org/) 是一个纯粹的 JavaScript 客户端版，随后也会成为 Logstash 的默认界面。和之前的版本不同的是，它不在依赖于一个类Logstash模式，而是可以用于任意Elasticsearch索引。

![](http://9791b61a81187466cf77-03e2fb40b56101ddc8886446c68cb0c1.r77.cf2.rackcdn.com/kibana%20events%202.png)

认证
============

到这步，我们已经解决了事件集中的问题，也有了丰富的API来深入解析日志。但是我们不想把所有日志都公开给每个人，所以我们需要一个认证，目前Elasticsearch 和 Kibana 都没提供认证功能，所以寄希望于 Elasticsearch API 是不可能的了。

我们选择了构建双层代理。一层代理用来做认证和流量限速，一层用来转义我们的事件 API 成 Elasticsearch 请求。前面这层代理我们已经以 Apache 2.0 开原协议发布在Github上，叫 [vulcan](https://github.com/mailgun/vulcan) 。我们还把我们原来的那套日志 API 也转移到了 Elasticsearch 系统上。

索引设计
============

有很多种方法来确定你如何组织自己的索引，基于文档的数目(每个时间段内)，以及查询模式。

Logstash 默认每天创建一个新索引，包括当天收到的全部时间。你可以通过配置修改这个时间，或者采用其他属性来区分索引，比如每个用户一个，或者用事件类型等等。

我们这里每秒有1500个时间，而且我们希望每个账户的轮转时间段都是可配置的。可选项有：

* 一个大索引。
* 每天一个索引。
* 每个用户账户一个索引。

当然，如果需要的话，这些都可以在未来进一步切分，比如根据事件类型。

管理轮滚的一个办法是在 Elasticsearch 中给每个文档设定 [TTLs](http://www.elasticsearch.org/guide/reference/mapping/ttl-field/) 。到了时间  Elasticsearch 就会批量删除过期文档。这种做法使得定制每个账户的轮转时间变得很简单，但是也带来了更多的 IO 操作。

另一个轻量级的办法是直接删除整个索引。这也是 Logstash 默认以天创建索引的原因。过了这天你直接通过 crontab 任务删除索引即可。

不过后面这个办法就没法定制轮转了。我们有很多用户账户，给每个用户每天保持一个索引是不切实际的。当然，给所有用户每天存一个索引又意味着我们要把所有数据都存磁盘上。如果一个账户是保持两天数据的轮转，那么在缓存中的数据就是有限的。在查询多天的垃圾邮件时，处理性能也就受限了。所以，我们需要保留更多的日志以供Kibana访问。

映射
============

为了定义文档(中的字段)如何压缩、索引和存储在索引里，Elasticsearch 有一个叫做 [mapping](http://www.elasticsearch.org/guide/reference/mapping/) 的概念。所以为每个字段它都定义了类型，定义了如何分析和标记字段的值以便索引和查询，定义了值是否需要存储，以及其他各种设置。默认的情况，mapping是动态的，也就是说 Elasticsearch 会从它获得的第一个值来尝试猜测字段的类型，然后正式应用这个设置到索引。

如果你的数据来源单一，这样就很好了。但实际可能来源很复杂，或者日志类型根本就不一样，比如我们这，同一个名字的字段的数据类型可能都不一样。 Elasticsearch 会拒绝索引一个类型不匹配的文档，所以我们需要自定义 mapping 。

通过我们的 [Events API](http://documentation.mailgun.com/api-events.html) ，我给日志事件的类型定义了一个映射。不是所有的事件都有所有这些字段，不过相同名字的字段肯定是一致的。

分析器
============

默认情况下，字段的 mapping 中就带有 标准分析器。简单的说，就是字符串会被转成小写，然后分割成一个一个单词。然后这些标记化的单词再写入银锁，并指向具体的字段。

有些情况，你可能想要些别的东西来完成不同的效果。比如说账户 ID，电子邮件地址或者网页链接 URL之类的，默认标记器会以斜线分割，而不考虑把整个域名作为一个单独的标记。当你通过 facet 统计域名字段的时候，你得到的会是域名中一段一段标签的细分结果。

要解决这个问题，可以设置索引属性，给对应字段设置成 `not_analyzed`。这样在插入索引的时候，这个字段不再经过映射或者标记器。比如对 `domain.name` 字段应用这个设置后，每个域名都会完整的作为同一个标签统计 facet 了。

如果你还想在这个字段内通过部分内容查找，你可以使用 [multi-field type](http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/)。这个类型可以映射相同的值到不同的核心类型或者属性，然后在不同名称下使用。我们对 IP 地址就使用了这个技术。默认的字段(比如叫`sending-ip`)的类型就是 ip，而另一个非默认字段(比如叫 `sending-ip.untouched`)则配置成 `not_analyzed` 而且类型为字符串。这样，默认字段可以做 IP 地址专有的范围查询，而 `.untouched` 字段则可以做 facet 查询。

除此以外，绝大多数字段我们都没用分析器和标记器。不过我们正在考虑未来可以结合上面的多字段类型技巧，应用 [pattern capture tokenfilter](http://www.elasticsearch.org/guide/reference/index-modules/analysis/pattern-capture-tokenfilter/) 到某些字段(比如电子邮件地址)上。

监控
============

要知道你的集群怎么样，你就必须要监控它。 Elasticsearch 有非常棒的 API 来获取 [cluster state](http://www.elasticsearch.org/guide/reference/api/admin-cluster-state/) 和 [node statistics](http://www.elasticsearch.org/guide/reference/api/admin-cluster-nodes-stats/)。我们可以用 [Graphite](http://graphite.wikidot.com/) 来存储这些指标并且做出综合表盘，下面就是其中一个面板：

![](http://9791b61a81187466cf77-03e2fb40b56101ddc8886446c68cb0c1.r77.cf2.rackcdn.com/graphite%20monitoring.png)

为了收集这些数据并且传输到 Graphite，我创建了 [Vör](http://github.com/mochi/vor)，已经在 [Mochi Media](http://www.mochimedia.com/) 下用 MIT/X11 协议开源了。另外一个保证 Redis 列表大小的收集器也在开发中。

除此以外，我们还统计很多东西，比如邮件的收发、点击数，API调用和耗时等等，这些是通过 [StatsD](https://github.com/etsy/statsd) 收集的，同样也添加到我们的 Graphite 表盘。

![](http://9791b61a81187466cf77-03e2fb40b56101ddc8886446c68cb0c1.r77.cf2.rackcdn.com/graphite%20events.png)

这绝对是好办法来观察发生了什么。Graphite 有一系列函数可以用来在绘图前作处理，也可以直接返回JSON文档。比如，我们可以很容易的创建一个图片展示 API 请求的数量与服务器负载或者索引速度的联系。

当前状况
============

我们的一些数据：

* 每天大概4kw 到 6kw 个日志事件。
* 30天轮转一次日志。
* 30个索引。 
* 每个索引5个分片。 
* 每个分片一个1副本。 
* 每个索引占 2 * 50 到 80 GB空间(因为有副本所以乘2)。

为此，我们启动了一共 9 台 Rackspace 云主机，具体配置是这样的：

* 6x 30GB RAM, 8 vCPUs, 1TB disk: Elasticsearch 数据节点。
* 2x 8GB RAM, 4 vCPUs: Elasticsearch 代理节点， Logstash， Graphite 和 StatsD。
* 2x 4GB RAM, 2 core: Elasticsearch 代理节点， Vulcan 和 API 服务器

大多数主机最终会迁移到专属的平台上，同时保留有扩展新云主机的能力。

Elasticsearch 数据节点都配置了 16GB 内存给 JVM heap。其余都是标准配置。此外还设置了 fieldcache 最大大小为 heap 的 40%，以保证集群不会在 facet 和 sort 内容很多的字段时挂掉。我们同时也增加了一点 [cluster wide settings](http://www.elasticsearch.org/guide/reference/api/admin-cluster-update-settings/) 来加速数据恢复和重均衡。另外，相对于我们存储的文档数量来说，`indices.recovery.max_bytes_per_sec` 的默认设置实在太低了。

总结
============

我们非常高兴用 Elasticsearch 来保存我们的事件，也得到了试用新 API 和新控制面板中新日志页面的客户们非常积极的反馈。任意字段的可搜索对日志挖掘绝对是一种显著的改善，而 Elasticsearch 正提供了这种高效无痛的改进。当然，Logstash，Elasticsearch 和 Kibana 这整条工具链也非常适合内部应用日志处理。

如果你想了解更多详情或者对我们的 API 有什么疑问，尽管留言。也可以在 Mailgun 博客上[阅读更多关于事件 API 的细节](http://blog.mailgun.com/post/new-events-api-detailed-email-tracking-and-search/)。

开心处理日志，开心发送邮件！

