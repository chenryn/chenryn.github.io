---
layout: post
theme:
  name: twitter
title: 如何搜索 Elasticsearch 中存储的动态请求 URL
category: logstash
tags:
  - elasticsearch
---

当我们用 logstash 处理 WEB 服务器访问日志的时候，肯定就涉及到一个后期查询的问题。

可能一般我们在 Kibana 上更多的是针对响应时间做数值统计，针对来源IP、域名或者客户端情况做分组统计。但是如果碰到这么个问题的时候呢——**过滤所有动态请求的响应时间**。

这时候你可能会发现一个问题：我们肯定都是用 URL 里带有问号? 来作为过滤条件。但是实际是 Kibana 里一条数据都过滤不出来。

于是我开测试库模拟了一下：

```bash
# 插入两条数据
curl http://localhost:9200/test/log/1 -d '{"url":"http://locahost/index.html"}'
curl http://localhost:9200/test/log/2 -d '{"url":"http://locahost/index.php?key=value"}'
# 搜索显示全部数据
curl http://localhost:9200/test/log/_search?pretty=1 -d '{"query":{"regexp":{"url":{"value":".*"}}}}'
# 搜索返回请求格式解析失败
curl http://localhost:9200/test/log/_search?pretty=1 -d '{"query":{"regexp":{"url":{"value":"\?.*"}}}}'
# 搜索返回空数据
curl http://localhost:9200/test/log/_search?pretty=1 -d '{"query":{"regexp":{"url":{"value":".*\\?.*"}}}}'
```

后来发现问题出在分词上面。

```bash
# 删除之前的测试数据和索引
curl -XDELETE http://localhost:9200/test/log
# 预定义索引类型的映射，url字段在索引的时候不分词
curl http://localhost:9200/test/log/_mapping -d '{"log":{"properties":{"url":{"index":"not_analyzed","type":"string"}}}}'
# 还是插入两条数据
curl http://localhost:9200/test/log/1 -d '{"url":"http://locahost/index.html"}'
curl http://localhost:9200/test/log/2 -d '{"url":"http://locahost/index.php?key=value"}'
# 同样的搜索请求，返回了一条结果(index.php?这条)
curl http://localhost:9200/test/log/_search?pretty=1 -d '{"query":{"regexp":{"url":{"value":".*\\?.*"}}}}'
```

上面这个搜索还可以简写成 Query DSL 的样式：

```
curl 'http://localhost:9200/test/log/_search?q=url:/.*\\?.*/&pretty=1'
```

而在 Logstash 比较新的 1.3.3 版本之后，有自带的 template 定义，会对每个 fields 采用 [multi-fields](http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/_multi_fields.html) 特性，也就是除了默认分词的 `URL` 字段以外，还有一个 `URL.raw` 字段都是不分词的。所以只要过滤这个字段就可以了。

(*注意，ES1.0版的multi-fields的template写法完全不一样了，所以要用这个特性的童鞋还是谨慎测试logstash和es的版本配套*)

Medcl 大神提示我：**不指定 mapping 的情况下，ES 默认采用 unigram 分词**。也就是切成尽可能小的单词。
