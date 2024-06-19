---
layout: post
theme:
  name: twitter
title: Elasticsearch 同一索引不同类型下同名字段的映射冲突实例
category: logstash
tags:
  - elasticsearch
---

这个标题肯定绕晕很多人吧。具体说明一下场景就明白了：Nginx 和 Apache 的访问日志，因为都属于网站访问，所以写入到同一个索引的不同类型下，比方 `logstash-accesslog-2015.04.03/nginx` 和 `logstash-accesslog-2015.04.03/apache`。既然都是访问日志，肯定很多字段的内容含义是雷同的，比如 clientip, domain, urlpath 等等。其中 nginx 有一个变量叫 `$request_time`，apache 有一个变量叫 `%T`，乍看上去也是同义的，我就统一命名为 "requestTime" 了。这就是"同一索引(logstash-accesslog-YYYY.MM.DD)下不同类型(nginx,apache)的同名字段(requestTime)"。

但事实上，这里有个问题：**nginx 中的以秒为单位，是把毫秒算作小数；apache 中的以秒为单位，是真的只记秒钟整数位！**

所以，这两个类型生成的映射在这个字段上是不一致的。nginx 类型的 requestTime 是 **double**，apache 类型的 requestTime 是 **long**。

不过平常看起来似乎也没什么影响，写入数据都照常，查看数据的时候默认显示的 JSON 也各自无异。直到我准备用一把 scripted field 的时候，发现计算 `doc['requestTime'].value * 1000` 得到的数都大的吓人！

因为类似计算之前在只有 nginx 日志入库的时候曾经正确运行过，所以只能是猜测 apache 日志对此造成了影响，但是即使我把请求修改成限定在 nginx 类型数据中进行，结果也没发生变化。

仔细阅读 scripting module 的文档，其中提到了 `doc['fieldname'].value` 和 `_source.fieldname` 两种写法的区别：**前者会利用内存中的数据，而后者强制读取磁盘上 `_source` 存储的 JSON 内容，从中释放出相应字段内容。**莫非是 requestTime 字段跟 `_source` JSON 里存的数据确实不一样，而我们平常搜索查看的都是从 JSON 里释放出来的，所以才会如此？

为了验证我的猜测，做了一个请求测试：

```bash
# curl es.domain.com:9200/logstash-accesslog-2015.04.03/nginx/_search?q=_id:AUx-QvSBS-dhpiB8_1f1\&pretty -d '{
    "fields": ["requestTime", "bodySent"],
    "script_fields" : {
        "test1" : {
            "script" : "doc[\"requestTime\"].value"
        },
        "test3" : {
            "script" : "_source.bodySent / _source.requestTime"
        },
        "test2" : {
            "script" : "doc[\"requestTime\"].value * 1000"
        }
    }
}'
```

得到的结果如下：

```json
{
  "took" : 43,
  "timed_out" : false,
  "_shards" : {
    "total" : 56,
    "successful" : 56,
    "failed" : 0
  },
  "hits" : {
    "total" : 1,
    "max_score" : 1.0,
    "hits" : [ {
      "_index" : "logstash-accesslog-2015.04.03",
      "_type" : "nginx",
      "_id" : "AUx-QvSBS-dhpiB8_1f1",
      "_score" : 1.0,
      "fields" : {
        "test1" : [ 4603039107142836552 ],
        "test2" : [ -8646911284551352000 ],
        "requestTime" : [ 0.54 ],
        "test3" : [ 2444.4444444444443 ],
        "bodySent" : [ 1320 ]
      }
    } ]
  }
}
```

果然！直接读取的字段，以及采用 `_source.fieldname` 方式读取的内容，都是正确的；而采用 `doc['fieldname'].value` 获取的内存数据，就不对。（0.54 存成 long 型会变成 4603039107142836552。这个 460 还正好能跟 540 凑成 1000，应该是某种特定存法，不过这里我就没深究了）

再作下一步验证。我们知道，ES 数据的映射是根据第一条数据的类型确定的，之后的数据如何类型跟已经成型的映射不统一，那么写入会失败。现在这个 nginx 和 apache 两个类型在 requestTime 字段上的映射是不一样的，但是内存里却并没有按照映射来处理。那么，我往一个类型下写入另一个类型映射要求的数据，会报错还是会通过呢？

```bash
# curl -XPOST es.domain.com:9200/test/t1/1 -d '{"key":1}'
{"_index":"test","_type":"t1","_id":"1","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t2/1 -d '{"key":2.2}'
{"_index":"test","_type":"t2","_id":"1","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t1/2 -d '{"key":2.2}'
{"_index":"test","_type":"t1","_id":"2","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t2/2 -d '{"key":1}'
{"_index":"test","_type":"t2","_id":"2","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t1/3 -d '{"key":"1"}'
{"_index":"test","_type":"t1","_id":"3","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t2/3 -d '{"key":"1"}'
{"_index":"test","_type":"t2","_id":"3","_version":1,"created":true}
# curl -XPOST es.domain.com:9200/test/t2/4 -d '{"key":"abc"}'
{"error":"RemoteTransportException[[10.10.10.10][inet[/10.10.10.10:9300]][indices:data/write/index]]; nested: MapperParsingException[failed to parse [key]]; nested: NumberFormatException[For input string: \"abc\"]; ","status":400}
# curl -XGET es.domain.com:9200/test/_mapping
{"test":{"mappings":{"t1":{"properties":{"key":{"type":"long"}}},"t2":{"properties":{"key":{"type":"double"}}}}}}
```

结果出来了，在映射相互冲突以后，实际数据只要是 numeric detect 能通过的，就都通过了！

BTW: kibana 4 中，已经会对这种情况以黄色感叹号图标做出提示；而根据官方消息，ES 未来会在 2.0 版正式杜绝这种可能。
