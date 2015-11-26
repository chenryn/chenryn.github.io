---
layout: post
title: 【Logstash系列】ElasticSearch的几点使用事项
category: logstash
tags:
  - elasticsearch
---
之前已经写过一些ES的使用，也翻译了一篇官网上关于ES存储日志的建议日志。今天稍微总结一下近期以来实践出来的方案。

# shard和replica的选择

在测试期，可以单节点上设置成1 shard + 0 replica的方式，这种的indexing速度是最快的(存疑:我至今没搞清楚ES在index的时候集群"应该"是比单node快还是慢)。

我曾经按照"常理"(我想象中的)理解，设定成10 shards + 0 replica，期望能用上并行写双node加倍index，事实上压根没用，而且因为另一台node上有其他负载的原因导致更慢了。

更可怕的是：就在前几天，突然出现一个shard挂了，……毫无办法，整个index全作废了。

所以结论是：无论如何，一定要保证有 > 0 份的replica!! 至于shards，保持默认的5个，或者顶多到20个也就差不多了。在maillist里看到有哥们设了100个，然后苦着脸问性能问题…… 要知道shards的份数是一旦设定不能更改的。

# template的使用

刚开始的时候，每次实验都去改/etc/elasticsearch/elasticsearch.yml配置文件。事实上在template里修改settings更方便而且灵活！当然最主要的，还是调节里面的properties设定，合理的控制store和analyze了。

template设定也有多种方法。最简单的就是和存储数据一样POST上去。长期的办法，就是写成json文件放在配置路径里。其中，default配置放在/etc/elasticsearch/下，其他配置放在/etc/elasticsearch/templates/下。举例我现在的一个templates/template-logstash.json内容如下：

```json
{
  "template-logstash" : {
    "template" : "logstash*",
    "settings" : {
      "index.number_of_shards" : 5,
      "number_of_replicas" : 1,
      "index" : {
        "store" : {
          "compress" : {
            "stored" : true,
            "tv": true
          }
        }
      }
    },
    "mappings" : {
      "_default_" : {
        "properties" : {
          "dynamic" : "true",
        },
      },
      "loadbalancer" : {
        "_source" : {
          "compress" : true,
        },
        "_ttl" : {
          "enabled" : true,
          "default" : "10d"
        },
        "_all" : {
          "enabled" : false
        },
        "properties" : {
          "@fields" : {
            "dynamic" : "true",
            "properties" : {
              "client" : {
                "type" : "string",
                "index" : "not_analyzed"
              },
              "domain" : {
                "type" : "string",
                "index" : "not_analyzed"
              },
              "oh" : {
                "type" : "string",
                "index" : "not_analyzed"
              },
              "responsetime" : {
                "type" : "double",
              },
              "size" : {
                "type" : "long",
                "index" : "not_analyzed"
              },
              "status" : {
                "type" : "string",
                "index" : "not_analyzed"
              },
              "upstreamtime" : {
                "type" : "double",
              },
              "url" : {
                "type" : "string",
                "index" : "not_analyzed"
              }
            }
          },
          "@source" : {
            "type" : "string",
            "index" : "not_analyzed"
          },
          "@timestamp" : {
            "type" : "date",
            "format" : "dateOptionalTime"
          },
          "@type" : {
            "type" : "string",
            "index" : "not_analyzed",
            "store" : "no"
          }
        }
      }
    }
  }
}
```

__注意：POST 发送的 json 内容比存储的 json 文件内容要少最外层的名字，因为名字是在 url 里体现的。__

# mapping简介

上面template中除了index/shard/replica之外的部分，就是mapping了，大家注意到其中的dynamic，默认情况下，index会在第一条数据进入的时候自动分析这条数据的情况，给每个value找到最恰当的type，然后以此为该index的mapping。之后再PUT上来的数据，格式如果不符合mapping的，也能存储成功，但是就无法检索了。

mapping中关于store和compress的部分，之前翻译的[《用ElasticSearch存储日志》](http://chenlinux.com/2012/08/26/translate-using-elasticsearch-for-logs)已经说的比较详细了。这里我的建议是 disable 掉 `_all`，但是 enable 住 `_source`!! 经过我的惨痛测试，如果连 `_source` 也 disable 掉的话，一旦你重启进程，整个 index 里除了 `_id`，`_timestamp` 和 `_score` 三个默认字段，啥都丢了……

# API简介

ES的API，最基本的就是CRUD操作了，这部分是标准的REST，就不说了。

然后还有三个API比较重要且常用，分别是: bulk/count/search。

* Bulk顾名思义，把多个单条的记录合并成一个大数组统一提交，这样避免一条条发送的header解析，索引频繁更新，indexing速度大大提高
* Count根据POST的json，返回命中范围内的总条数。当然没POST时就直接返回该index的总条数了。
* Search根据POST的json或者GET的args，返回命中范围内的数据。这是最重要的部分了。下面说说常用的search API：

## query

一旦使用search，必须至少提供query参数，然后在这个query的基础上进行接下来其他的检索。query参数又分三类：

* `"match_all" : { }` 直接请求全部；
* `"term"/"text"/"prefix"/"wildcard" : { "key" : "value" }` 根据字符串搜索(严格相等/片断/前缀/匹配符);
* `"range" : { "@timestamp" : { "from" : "now-1d", "to" : "now" } }` 根据范围搜索，如果type是时间格式，可以使用内置的now表示当前，然后用-1d/h/m/s来往前推。

## filter

上面提到的query的参数，在filter中也都存在。此外，还有比较重要的参数就是连接操作：

* `"or"/"and" : [{"range":{}}, {"prefix":""}]` 两个filter的查询，交集或者合集；
* `"bool" : ["must":{},"must_not":{},"should":{}]` 上面的and虽然更快，但是只能支持两个，超过两个的，要用 bool 方法；
* `"not"/"limit" : {}` 取反和限定执行数。注意这个limit和mysql什么的有点不同：它限定的是在每个shards上执行多少条。如果你有5个shards，其实对整个index是limit了5倍大小的设定值。

另一点比较关键的是：filter结果默认是不缓存的，如果常用，需要指定 `"_cache" : true`。

## facets

facets接口可以根据query返回统计数据，最基础的是terms和statistical两种。不过在日志分析的情况下，最常用的是：

* `"histogram" : { "key_field" : "", "value_field" : "", "interval" : "" }` 根据时间间隔返回柱状图式的统计数据；
* `"terms_stats" : { "key_field" : "", "value_field" : "" }` 根据key的情况返回value的统计数据，类似group by的意思。

这里就涉及到前面mapping里为什么针对每个field都设定type的原因了。因为 `histogram` 里的 `key_field` 只能是 `dateOptionalTime` 格式的，`value_field` 只能是 `string` 格式的；而 `terms_stats` 里的 `key_field` 只能是 `string` 格式的，`value_field` 只能是 `numberic` 格式的。

而我们都知道，http code那些200/304/400/503神马的，看起来是数字，我们却需要的是他们的count数据，不是算他们的平均数。所以不能由ES动态的认定为long，得指定为string。

# analyze简介

对于logstash分析日志，基本没有提到analyze的部分，包括Kibana也是。但是做web日志分析，其实也需要注意analyze。因为ES默认提供并开启了一些analyze。最简单的比如空格分隔表示单词，斜线分割表示url路径，@分割表示email地址等等。文档地址见<http://www.elasticsearch.org/guide/reference/index-modules/analysis/>。当然ES社区的中国人也有提供中文分词的plugin。通常情况下，analyze工作的很好。嗯，ES比其他全文索引工具在默认情况下都工作的好。

但是当你想算的是今天访问的url排名，或者来访者IP排名的时候，麻烦来了，你苦苦等待N久，最后一看排名是这样的：

    jpg  2345678
    html 123456
    20121021 34567
    bbs 9876

对，你的url被ES辛辛苦苦的用 / 和 . 分割了，然后每个单词排序来再返回给你。如果你是在一个数千万条的大型库上运行的话，基本吃个饭回来才能有结果。

事实上，url就是一个整体，所以在mapping中，要定义好在indexing的时候，不要启用analyzer。这样，返回一个你心目中想要的正确的url排名，时间从吃个午饭直接缩减到打个喷嚏了！而如果是访问者ip，时间则是眨下眼就够了！

注意：analyze不是只有indexing的时候能用，在query的时候，也可以单独指定某个analyze来分析记录。analyze其实是和search并列的API，不过目前场景下用不上，就不说了。

有以上API，基本上一个针对logstash的ES数据分析系统后台就足够构建出来了。剩下的就是前端页面的事情，这方面可以参考logstash的Kibana，更广义一些的ES数据可视化可以参考ES的blog: <http://www.elasticsearch.cn/blog/2011/05/13/data-visualization-with-elasticsearch-and-protovis.html>，笔者的译文见<http://chenlinux.com/2012/11/18/data-visualization-with-elasticsearch-and-protovis>。

# 性能监控

ES周边的工具有很多。目前我主要用三种方式：

* es\_head: 这个主要提供的是健康状态查询，当然标签页里也提供了简单的form给你提交API请求。es\_head现在可以直接通过 `elasticsearch/bin/plugin -install mobz/elasticsearch-head` 安装，然后浏览器里直接输入 `http://$eshost:9200/_plugin/head/` 就可以看到cluster/node/index/shards的状态了。
* bigdesk: 这个主要提供的是节点的实时状态监控，包括jvm的情况，linux的情况，elasticsearch的情况。排查性能问题的时候很有用，现在也可以通过 `elasticsearch/bin/plugin -install lukas-vlcek/bigdesk` 直接安装了。然后浏览器里直接输入 `http://$eshost:9200/_plugin/bigdesk/` 就可以看到了。注意如果使用的 `bulk_index` 的话，如果选择的刷新间隔太长，indexing per second数据是不准的。
* 然后是最基础的办法，通过ES本身的status API获取状态。因为上面都是web工具，如果想要避免上文提到的故障很久才发现的问题，我们需要一个可以提供给nagios使用的办法，这很简单就可以做到。刚巧ES本身也有green/yellow/red等不同的状态。所以很简单完成一个check_es_health.sh如下：

```bash
#!/bin/sh
    ES_HOST=$1
    ES_URI="http://${ES_HOST}:9200/_cluster/health"
    RES_JSON=`curl -s ${ES_URI}`
    
    status=`echo ${RES_JSON}|awk -F\" '{print $8}'`
    failed=`echo ${RES_JSON}|awk -F\" '{print $NF}'|sed 's/^:\([0-9]*\)}/\1/'`
    
    if [[ "$status" -eq "green" ]];then
        echo "ES Cluster OK | failed_node=${failed}"
        exit 0
    elif [[ "$status" -eq "yellow" ]];then
        echo "Warning! ES Cluster shards relocating or initializing. | failed_node=${failed}"
        exit 1
    else
        echo "Critical! ES Cluster shards unassigned. | failed_node=${failed}"
        exit 2
    fi
```

# 其他插件

ES是一个很活跃的开源项目，所以如果有其他目前ES没有你有觉得有需要的功能，大可以上github搜索一下，或许别人早已经做完相关插件了。

比如我就在上面找到一个plugin叫elasticfacets。加强了ES的 `date_histogram` 功能，原先只能针对某个 `value_field` 做攻击，这个plugin可以在这个基础上，把 `value_field` 加强成又一层facets。项目地址: <https://github.com/bleskes/elasticfacets>。之前和作者反馈了在ES 0.19.8上的问题，不知道修复没。或许最好还是用0.19.9吧。

# 邮件列表

ES的邮件列表基本每天都有四五十封邮件，地址是：<elasticsearch@googlegroups.com>。

