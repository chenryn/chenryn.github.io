---
layout: post
title: 山寨一个 Splunk 的 source 上下文查看功能
category: logstash
tags:
  - elasticsearch
  - splunk
---

跟很多朋友在聊 elk stack 的时候，都会不知不觉的开始跟 Splunk 做对比。最常见的两个抱怨就是：Splunk 的搜索构建语法 比 Kibana 方便，以及 Splunk 搜索出来的消息可以通过点击 `Source` 按钮查看其原始日志中的前后几条日志。

![splunk source context](/images/uploads/splunk-source-context.jpg)

平心而论，这个上下文查找的功能确实在排错过程中非常有用。但是在 elk 里却不那么容易实现，原因是：

**elasticsearch 是一个分布式项目，其索引的 `_id` 默认使用的是 UUID 方式生成的随机字符串，你没法根据 UUID 来判断数据的先后。**

`LogStash::Outputs::Elasticsearch` 提供了让你指定 `_id` 内容的选项，但是在集群环境下，你很难自己搞定一个全局自增 ID。

*相反，虽然我不知道 splunk 的数据存储的内部实现，但是就他昂贵的报价来说，基本只见过单机案例。就单机而言，自增 id 太轻松了*

所以，从原理上来说，就很难实现一个通用的 elk 版上下文查看功能。

不过我们缩小一下使用场景，却未必不能自己山寨一个对自己可用的办法来。

假设我们一个最常见的场景，就是从各 web 服务器上收集不同日志到中心。那么这时候，通过 `%{host}` 和 `%{path}` 的 "AND" 过滤，我们就可以把范围缩小到一个单一的文件内容里。所以，我们只需要能够搞定这个文件的自增 id 就够了！

## logstash.conf 示例

```ruby
input {
    file {
        path => ["/var/log/*.log"]
    }
}
filter {
    ruby {
        init => '@incr={}'
        code => "key = event['host']+event['path']
                 if @incr.has_key?(key)
                     @incr[key] += 1
                 else
                     @incr[key] = 1 
                 end
                 event['lineno'] = @incr[key]"
    }
}
output {
    elasticsearch {
    }
}
```

## 上下文查询 curl 示例

使用上面的配置运行起来 logstash 之后，假设我们现在搜到一条 syslog 日志，其 `lineno` 是 20，那么查看它的前后 5 条记录的 curl 命令就是：

```json
curl -XPOST 'http://localhost:9200/logstash-2014.08.29/_search?pretty=1' -d '
{
  "query":{
    "range":{
      "lineno": {
        "gt":15,
        "lte":25
      }
    }   
  },  
  "filter":{
    "term":{
      "host.raw":"raochenlindeMacBook-Air.local",
      "path.raw":"/var/log/system.log"
    }
  },
  "sort":[{"lineno":"asc"}],
  "fields":["message"],
  "size":10
}'
```

得到的结果是：

```json
{
  "took" : 3,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "failed" : 0
  },
  "hits" : {
    "total" : 10,
    "max_score" : null,
    "hits" : [ {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "ILkv4oZOQRGXkH5nxjPT6Q",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:34:44 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391727104]: Service [sproxy] accepted connection from 127.0.0.1:52673" ]
      },
      "sort" : [ 16 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "frRzVZUDQr-dkRog9LEypQ",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:34:44 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391727104]: s_connect: connected 50.116.12.155:65080" ]
      },
      "sort" : [ 17 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "fQ50VrbuSfy6AmhNOaHpFg",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:34:44 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391727104]: Service [sproxy] connected remote server from 192.168.0.102:52674" ]
      },
      "sort" : [ 18 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "Bpza8x6gSQi3OFRfAz3vPA",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:35:23 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391882752]: Service [sproxy] accepted connection from 127.0.0.1:52710" ]
      },
      "sort" : [ 19 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "I7SQ4o-aSr--em1WXO0y0A",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:35:24 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391882752]: s_connect: connected 50.116.12.155:65080" ]
      },
      "sort" : [ 20 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "POLq7XA_QVe6E5f9cP9V-w",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:35:24 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391882752]: Service [sproxy] connected remote server from 192.168.0.102:52711" ]
      },
      "sort" : [ 21 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "sXCLVr7URu-2uKhcOP3wjA",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:35:35 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391882752]: Connection closed: 0 byte(s) sent to SSL, 0 byte(s) sent to socket" ]
      },
      "sort" : [ 22 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "3wxxElNuS7OgyvjSm8CQfg",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:36:25 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391571456]: Connection closed: 2825 byte(s) sent to SSL, 2407 byte(s) sent to socket" ]
      },
      "sort" : [ 23 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "xdsiB1cmRpagWiMxtAjMzQ",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:36:52 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391493632]: Connection closed: 1109 byte(s) sent to SSL, 583 byte(s) sent to socket" ]
      },
      "sort" : [ 24 ]
    }, {
      "_index" : "logstash-2014.08.29",
      "_type" : "logs",
      "_id" : "mLScPMbwTzSPMz9WqOPXlw",
      "_score" : null,
      "fields" : {
        "message" : [ "Aug 29 23:36:52 raochenlindeMacBook-Air.local stunnel[304]: LOG5[4391571456]: Service [sproxy] accepted connection from 127.0.0.1:52719" ]
      },
      "sort" : [ 25 ]
    } ]
  }
}
```

没错，这就是我们想要的结果了！

**注释**

这里两个要点：

* 自增 id 为啥不用行号，因为 `LogStash::Inputs::File` 实现是通过 `File.seek` 和 `File.sysread(16394)` 完成的，这种时候 `File.lineno` 永远都是 0。获取真的行号很困难。
* 自增 id 为什么不指定成 `_id` 而是另外存字段，因为 `_id` 是特殊字段，要求在一个 `_index/_type` 里是唯一的。我们对 logstash 的使用一般情况下都是多个 host 内容存在同一个 `_index/_type` 下，会发生重复的(重复写入 `_id` 相同的数据等同于 `update` 操作)。

## 延伸

数据如何通过 kibana 展示，则是另外一个层面的内容。有时间可能我会也做一下。

非 input/file 方式的其他场景，只要你能通过 event 中其他字段确定出来源唯一，都可以采用这个方式做。
