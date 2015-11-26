---
layout: post
title: 利用脚本灵活定制 Elasticsearch 中的聚合效果
category: logstash
tags:
  - elasticsearch
  - groovy
---

这几天阅读 Splunk 书，发现 Splunk 作为一个不需要提前结构化数据的处理工具，在自动发现的 "interesting fields" 以外，也提供了在页面通过正则临时产生新字段的能力。类似下面这样：

    sourcetype="impl_splunk_gen"
      | rex "ip=(?P<subnet>\d+\.\d+\.\d+)\.\d+"
      | chart values(subnet) by user network

这就蛮让人流口水的了。毕竟谁也不可能保证自己在结构化的时候做到了万事俱备。不过，ELK 虽然建议大家在 logstash 里通过 grok 来预处理，其实本身也是有这个能力的。今天稍微测试了一下，通过 ES 的 **scripting** 模块，完全可以实现这个效果。

*测试在 Elasticsearch 1.4.1 上进行。较低的版本可能在支持的语言方面稍有差异。*

因为 scripting 在早先 1.2 的时候出过安全问题，所以后来就都不再允许直接通过 POST 的内容里提交 scripting 代码了。现在有两种方式，一种是在 elasticsearch-1.4.1/config/ 目录下新建一个 scripts 目录，然后把准备要用的脚本都放在这个目录里，ES 会自动探测并加载编译；另一种是开启动态 scripting 功能，再通过 `/_script` 接口上传脚本。

下面示例两种实现获取 client_ip 字段的 C 段的统计的方式：

1. 通过简单的切割合并

创建 `config/scripts/split.groovy` 文件，内容如下：

```java
doc[fieldname].value.split('.')[0..-2].join('.')
```

稍等一下，看到 ES 的日志显示探测到并且编译成功后。就可以发送请求了：

    curl '127.0.0.1:9200/logstash-2014.11.27/_search?pretty&size=0' -d '{
        "aggs" : {
            "ipaddr" : {
                "terms" : {
                    "script" : "split",
                    "params" : {
                        "fieldname": "client_ip.raw"
                    }
                }
            }
        }
    }'

**注意这里一定要传递是 "not_analyzed" 的 字段过去！** ES 流程上是先过分词器再到 scripting 模块的，这里要是切一下，到你脚本里就不知道长啥样了……

结果如下：

```json
{
  "took" : 30,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "failed" : 0
  },
  "hits" : {
    "total" : 786,
    "max_score" : 0.0,
    "hits" : [ ]
  },
  "aggregations" : {
    "ipaddr" : {
      "doc_count_error_upper_bound" : 0,
      "sum_other_doc_count" : 0,
      "buckets" : [ {
        "key" : "127.0.0",
        "doc_count" : 786
      } ]
    }
  }
}
```

2. 通过正则捕获

前面的方式虽然达到目的，但是不像 splunk 的做法那么通用，所以更高级的是这样：

创建 `config/scripts/regex.groovy` 文件，内容如下：

```java
matcher = ( doc[fieldname].value =~ /${pattern}/ )
if (matcher.matches()) {
    matcher[0][1]
}
```

同样等识别编译，然后发送这样的请求：

    curl '127.0.0.1:9200/logstash-2014.11.27/_search?pretty&size=0' -d '{
        "aggs" : {
            "ipaddr" : {
                "terms" : {
                    "script" : "regex",
                    "params" : {
                        "fieldname": "client_ip.raw",
                        "pattern": "^((?:\d{1,3}\.?){3})\.\d{1,3}$"
                    }
                }
            }
        }
    }'

得到一模一样的结果。

下一次试验一下在脚本中尝试加载其他库做更复杂处理的话，会如何呢？
