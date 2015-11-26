---
layout: post
title: 【翻译】Elasticsearch 1.4.0 beta 1 发版日志
category: logstash
tags:
  - elasticsearch
---

原文见：<http://www.elasticsearch.org/blog/elasticsearch-1-4-0-beta-released/>

--------------------

今天，我们很高兴公告基于 **Lucene 4.10.1** 的 **Elasticsearch 1.4.0.Beta1** 发布。你可以从这里下载并阅读完整的变更列表：[Elasticsearch 1.4.0.Beta1](http://www.elasticsearch.org/downloads/1-4-0-Beta1)。

1.4.0 版的主题就是**弹性**：让 Elasticsearch 比过去更稳定更可靠。当所有东西都按照它应该的样子运行的时候，就很容易变得可靠了。但是不在意料中的事情发生时，复杂的部分就来了：节点内存溢出，它们的性能被慢垃圾回收或者超重的 I/O 拖累，网络连接失败，或者数据传输不规律。

这次 beta 版主要在三方面力图改善弹性：

* 通过减少[内存使用](#section)提供更好的节点稳定性。
* 通过改进发现算法提供更好的[集群稳定性](#section-1)。
* 通过[checksums](#checksums)提供更好的数据损坏检测。

分布式系统是复杂的。我们已经有一个广泛的测试套件，可以创建随机场景，模拟我们自己都没想过的条件。但是依然会有无限多在此范围之外的情况。1.4.0.Beta1 里已经包含了我们目前能做到的各种优化努力。真心期望大家在实际运用中测试这些变更，然后[告诉我们你碰到的问题](https://github.com/elasticsearch/elasticsearch/issues)。

## 内存管理

* 内存压力
* swap (参见 [memory settings](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/setup-configuration.html#setup-configuration-memory))
* 太大的 heaps

这次发版包括了一系列变更来提升内存管理，并由此提升节点稳定性：

### doc values

*fielddata* 是最主要的内存大户。为了让聚合、排序以及脚本访问字段值时更快速，我们会加载字段值到内存，并保留在内存中。内存的堆空间非常宝贵，所以内存里的数据需要使用复杂的压缩算法和微优化来完成每次计算。正常情况下这样会工作的很好，直到你的数据大小超过了堆空间大小。这个问题看起来可以通过添加更多节点的方式解决。不过通常来说，堆空间问题总是会在 CPU 和 I/O 之前先到达瓶颈。

现有版本已经添加了 doc values 支持。本质上，doc values 提供了和内存中 fielddata 一样的功能，不过他们在写入索引的时候就直接落到了磁盘上。而好处就是：他们**消耗很少的堆空间**。Doc values 在读取的时候也不是从内存，而是从磁盘上读取。虽然访问磁盘很慢，但是 doc values 可以利用内核的文件系统缓存。文件系统缓存可不像 JVM 的堆，不会有 32GB 的限制。所以把 fielddata 从堆转移到文件系统缓存里，你只用消耗更小的堆空间，也意味着更快的垃圾回收，以及**更稳定的节点**。

在本次发版之前，doc values 明显慢于在内存里的 fielddata 。而这次我们显著提升了性能，几乎达到了和在内存里一样快的效果。

用doc values 替换内存 fielddata，你只需要向下面这样构建新字段就行：

```json
PUT /my_index
{
  "mappings": {
    "my_type": {
      "properties": {
        "timestamp": {
          "type":       "date",
          "doc_values": true
        }
      }
    }
  }
}
```

有了这个映射表，要用这个字段数据都会自动从磁盘加载 doc values 而不是进到内存里。**注意**：目前 doc values 还不能在经过分词器的 `string` 字段上使用。

### request circuit breaker

fielddata 断路器之前已经被加入，用作限制 fielddata 可用的最大内存，这是导致 OOM 的最大恶因。而限制，我们把这个机制扩展到[请求界别](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/index-modules-fielddata.html#request-circuit-breaker)，用来限制每次请求可用的最大内存。

### bloom filters

[Bloom filters](http://en.wikipedia.org/wiki/Bloom_filter) 在写入索引时提供了重要的性能优化 -- 用以检查是否有已存在的文档 id ，在通过 id 访问文档时，用来探测哪个 segment 包含这个文档。不过当然的，这也有代价，就是内存消耗。目前的改进是移除了对 bloom filters 的依赖。目前 Elasticsearch 只在写入索引(仅是真实用例上的经验，没有我们的测试用例证明)的时候构建它，但[默认](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/indices-update-settings.html#codec-bloom-load)不再加载进内存。如果一切顺利的话，未来的版本里我们会彻底移除它。

## 集群稳定性

提高集群稳定性最大的工作就是提高节点稳定性。如果节点稳定且响应及时，就极大的减少了集群不稳定的可能。换句话说，我们活在一个不完美的世界 -- 事情总是往意料之外发展，而集群就需要能无损的从这些情况中恢复回来。

我们在 improve_zen 分支上花了几个月的时间来提高 Elasticsearch 从失败中恢复的能力。首先，我们添加测试用例来复原复杂的网络故障。然后为每个测试用例添加补丁。肯定还有很多需要做的，不过目前来说，用户们已经碰到过的绝大多数问题我们已经解决了，包括[issue #2488](https://github.com/elasticsearch/elasticsearch/issues/2488) -- "minimum_master_nodes 在交叉脑裂时不起作用"。

我们非常认真的对待集群的弹性问题。希望你能明白 Elasticsearch 能为你做什么，也能明白它的弱点在哪。考虑到这点，我们创建了[弹性状态文档](http://www.elasticsearch.org/guide/en/elasticsearch/resiliency/current/index.html)。这个文档记录了我们以及我们的用户碰到过各种弹性方面的问题，有些可能已经修复，有些可能还没有。请认真阅读这篇文档，采取适当的措施来保护你的数据。

## 数据损坏探测

从网络恢复过来的分片的 checksum 帮助我们发现过一个压缩库的 bug，这是 1.3.2 版本的时候发生的事情。从那天起，我们给 Elasticsearch 添加了越来越多的 checksum 认证。

* 在合并时，segment 中的所有文件都有自己的 checksum 验证([#7360](https://github.com/elasticsearch/elasticsearch/issues/7360)).
* 重新开所有索引的时候，segment 里的小文件完整的验证，大文件则做轻量级的分段验证([LUCENE-5842](https://issues.apache.org/jira/browse/LUCENE-5842)).
* 从 transaction 日志重放事件的时候，每个事件都有自己的 checksum 验证([#6554](https://github.com/elasticsearch/elasticsearch/issues/6554)).
* During shard recovery, or when restoring from a snapshot, Elasticsearch needs to compare a local file with a remote copy to ensure that they are identical. Using just the file length and checksum proved to be insufficient. Instead, we now check the identity of all the files in the segment ([#7159](https://github.com/elasticsearch/elasticsearch/issues/7159)).

## 其他亮点

你可以在 [Elasticsearch 1.4.0.Beta1 changelog](http://www.elasticsearch.org/downloads/1-4-0-Beta1) 里读到这个版本的所有特性，功能和修复。不过还是有些小改动值得单独提一下的：

### groovy 代替了 mvel

Groovy 现在成为了新的默认脚本语言。之前的 MVEL 太老了，而且它不能运行在沙箱里也带来了安全隐患。Groovy 是沙箱化的(这意味着可以放心的开启)(译者注：还记得1.2版本时候的所谓安全漏洞吧)，而且 Groovy 有个很好的管理团队，运行速度也**很快**！更多信息见[博客关于脚本的内容](http://www.elasticsearch.org/blog/scripting/)。

### 默认关闭 cors

默认配置下的 Elasticsearch 很容易遭受跨站攻击。所以我们默认关闭掉 [CORS](http://en.wikipedia.org/wiki/Cross-origin_resource_sharing)。Elasticsearch 里的 site 插件会照常工作，但是外部站点不再被允许访问远程集群，除非你再次打开 CORS。我们还添加了更多的[CORS 配置项](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/modules-http.html#_settings_2)让你可以控制哪些站点可以被允许访问。更多信息请看我们的[安全页](http://www.elasticsearch.org/community/security)。

### 请求缓存(query cache)

一个新的实验性[分片层次的请求缓存](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/index-modules-shard-query-cache.html)可以让在静态索引上的聚合请求瞬间返回响应。想想你有一个仪表板展示你的网站每天的 PV 数。这个书在过去的索引上不可能再变化了，但是聚合请求在每次页面刷新的时候都需要重新计算。有了新的请求缓存，聚合结果就可以直接从缓存中返回，除非分片中的数据发生了变化。你不用担心会从缓存中得到过期的结果 -- 它永远都会跟没缓存一样。

### 新的聚合函数

我们添加了三个新的聚合函数：

`filters`

    这是 `filter` 聚合的扩展。允许你定义多个桶(bucket)，每个桶里有不同的过滤器。

`children`

    相当于 `nested` 的父子聚合，`children` 可以针对属于某个父文档的子文档做聚合。

`scripted_metric`

    给你完全掌控数据数值运算的能力。提供了在初始化、文档收集、分片层次合并，以及全局归并阶段的钩子。

### 获取 /index 的接口

之前，你可以分别为一个索引获取他的别名，映射表，配置等等。而[`get-index` 接口](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/indices-get-index.html) 现在让你可以一次获取一个或者多个索引的全部信息。这在你需要创建一个跟已有索引很类似或者几乎一样的新索引的时候，相当有用。

### 索引写入和更新

在文档写入和更新方面也有一些改进：

* 我们现在用 [Flake IDs](http://boundary.com/blog/2012/01/12/flake-a-decentralized-k-ordered-unique-id-generator-in-erlang) 自动生成文档的 ID。在查找主键的时候，能提供更好的性能。
* 如果设置 `detect_noop` 为 `true`，一个不做任何实际变动的更新操作现在消耗更小了。打开这个参数，就只有变更了 `_source` 字段内容的更新请求才能写入新版本文档。
* 更新操作可以完全由脚本控制。之前，脚本只能在字段已经存在的时候运行，否则会插入一个 `upsert` 文档。现在 `scripted_upsert` 参数允许你在脚本中直接处理文档创建工作。

### function score

非常有用的 [`function_score` 请求](http://www.elasticsearch.org/guide/en/elasticsearch/reference/1.4/query-dsl-function-score-query.html)现在支持权重参数，用来优化每个指定函数的相关性影响。这样你可以把更多权重给新近的而不是热点的，给价格而不是位置。此外，`random_score`函数不再被 segment 合并影响，增强了排序一致性。

## 试一试

请[下载 Elasticsearch 1.4.0.Beta1](http://www.elasticsearch.org/downloads/1-4-0-Beta1)，尝试一下，然后在 Twitter 上[@elasticsearch](https://twitter.com/elasticsearch)) 说出你的想法。你也可以在 [GitHub issues 页](https://github.com/elasticsearch/elasticsearch/issues)上报告问题。
