---
layout: post
theme:
  name: twitter
title: 山寨一个 Splunk 的事件模式功能
category: logstash
tags:
    - elasticsearch
    - splunk
---

之前我曾经讲过一个简单的在 ELK 中山寨 Splunk 的『显示来源』功能的办法。这次我们玩个更有难度的、当然依然只是山寨式功能的新东西：『事件模式』功能。

Splunk 6.2 推出的这个功能，会基于当前搜索语句的结果集做模式探测，根据精度调整，做成不同数量的聚类。然后给每个聚类分组内，提取出一个关键词（个别情况下也有零个或多个的）。也就是通过机器学习的手段，探测你的日志可能有什么模式，其最具识别性的关键内容是什么。

![Event Pattern](/images/uploads/splunk-event-pattern.png)

这个页面如果用 SPL 表示，就是：`index=_internal | cluster t=0.8 lableonly=true | findkeywords labelfield=cluster_label | sort - percentInputGroup`

![findkeywords command](/images/uploads/splunk-findkeywords.png)

我们目前当然在 ES 里是没法做聚类分析什么的了。不过在日志场景下，也不是没有近似的办法。

### 第一步：完成山寨版的日志模式分组

其实如何山寨模式分组，Splunk 也有类似 SPL 命令做出了示范。这个命令叫 `typelearner`。

这个命令的大致意思是：把日志里的英文单词、数字、空格等字符都隐藏掉，剩下各种标点符号，就代表一种日志类型。简单的处理方式就是：

```bash
cat samplelog.cisco.asa |sed 's/[0-9a-zA-Z]*//g' | sed 's/[[:space:]]/_/g'
```

然后将这个纯标点符号的字符串，存为事件的一个字段，我们沿袭 Splunk 的叫法： **punct** 。

这样，我们只要简单的对 punct 字段做 `terms aggregation` 就可以获取模式分组了。

### 第二步：完成分组内的关键词查找

然后查找关键词。什么叫关键词呢？就是要能让本分组跟其他分组有显著差异的一个词。这个显然不能再用 terms aggregation 了。否则出来的是最多的词，而不是最有差异性的词。ES 对这个也提供了现成的聚合方式：`significant_terms aggregation`。

然后这里有另一个问题：一般我们都是在 `not_analyzed` 字段上做聚合统计的。现在显然并没有具体哪个字段来提供单个字段值做聚合！我们需要用的就是**分词的日志原文内容**。

所以这块我们需要对原文字段的 mapping 做出特殊定义：

```json
    "message": {
        "type": "text",
        "fielddata": true,
        "index_options": "docs",
        "norms": false
    },
```

即重新放开 fielddata —— ES 5.0 里，text 类型字段已经默认关闭 fielddata 了。

至于内存的问题，或者交给 Circuit Breaker 来控制；或者自己通过请求中的 `terminate_after` 参数预先控制。

就模式发现这个功能来说，通过 `terminate_after` 参数预定义控制应该是个不错的思路。因为本来就是一个不确定的猜测，加太大的数据量来做这事儿，没多少性价比。

所以我们最终发出的请求是这样：

```bash
#!/bin/bash
curl -XPOST 'http://localhost:9200/logstash-2016.07.18/logs/_search?pretty&terminate_after=30000&size=0' -d '
{
    "aggs": {
        "group": {
            "terms": {
                "field": "punct"
            },
            "aggs": {
                "keyword": {
                    "significant_terms": {
                        "size": 1,
                        "field": "message"
                    },
                    "aggs": {
                        "hit": {
                            "top_hits": {
                                "_source": {
                                    "include": [ "message"  ]
                                },
                                "size":1
                            }
                        }
                    }
                }
            }
        }
    }
}
'
```

我们可以看到请求结果如下：

```json
{
  "took" : 2179,
  "timed_out" : false,
  "terminated_early" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 2,
    "failed" : 3,
    "failures" : [ {
      "shard" : 0,
      "index" : "logstash-2016.07.18",
      "node" : "L0qQ1ZcyQGmj7Ge7ZlCmYg",
      "reason" : {
        "type" : "circuit_breaking_exception",
        "reason" : "[request] Data too large, data for [<reused_arrays>] would be larger than limit of [415550668/396.2mb]",
        "bytes_wanted" : 415762160,
        "bytes_limit" : 415550668
      }
    } ]
  },
  "hits" : {
    "total" : 371095,
    "max_score" : 0.0,
    "hits" : [ ]
  },
  "aggregations" : {
    "group" : {
      "doc_count_error_upper_bound" : 72,
      "sum_other_doc_count" : 93355,
      "buckets" : [ {
        "key" : "--_::._+____-_=,_=,_=,_=.,_=,_=",
        "doc_count" : 98100,
        "keyword" : {
          "doc_count" : 98100,
          "buckets" : [ {
            "key" : "cpu_seconds",
            "doc_count" : 98100,
            "score" : 2.2037623779471813,
            "bg_count" : 115831,
            "hit" : {
              "hits" : {
                "total" : 98100,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUujh",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:33.776 +0800 INFO  Metrics - group=pipeline, name=indexerpipe, processor=index_thruput, cpu_seconds=0.000000, executes=111, cumulative_hits=161675"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=,_=,_=,_=,_=",
        "doc_count" : 87058,
        "keyword" : {
          "doc_count" : 87058,
          "buckets" : [ {
            "key" : "largest_size",
            "doc_count" : 75663,
            "score" : 2.835574761742766,
            "bg_count" : 75663,
            "hit" : {
              "hits" : {
                "total" : 75663,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUuj9",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:02.780 +0800 INFO  Metrics - group=queue, name=nullqueue, max_size_kb=500, current_size_kb=0, current_size=0, largest_size=1, smallest_size=0"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=\"\",_=.,_=.,_=.,_=,_=.,_=",
        "doc_count" : 26317,
        "keyword" : {
          "doc_count" : 26317,
          "buckets" : [ {
            "key" : "max_age",
            "doc_count" : 26317,
            "score" : 7.224805514306611,
            "bg_count" : 45119,
            "hit" : {
              "hits" : {
                "total" : 26317,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUukH",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:02.780 +0800 INFO  Metrics - group=per_sourcetype_thruput, series=\"scheduler\", kbps=0.014869, eps=0.032258, kb=0.460938, ev=1, avg_age=0.000000, max_age=0"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=\"//////.\",_=.,_=.,_=.,_=,_=.,_=",
        "doc_count" : 13063,
        "keyword" : {
          "doc_count" : 13063,
          "buckets" : [ {
            "key" : "log",
            "doc_count" : 13063,
            "score" : 27.241628614916287,
            "bg_count" : 13140,
            "hit" : {
              "hits" : {
                "total" : 13063,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMKILjo3PexoUulQ",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:16:31.780 +0800 INFO  Metrics - group=per_source_thruput, series=\"/applications/splunk/var/log/splunk/metrics.log\", kbps=0.326188, eps=2.032164, kb=10.112305, ev=63, avg_age=0.968254, max_age=1"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=.,_=.,_=.,_=.,_=.,_=.",
        "doc_count" : 11603,
        "keyword" : {
          "doc_count" : 11603,
          "buckets" : [ {
            "key" : "average_kbps",
            "doc_count" : 11603,
            "score" : 20.38013481592441,
            "bg_count" : 17357,
            "hit" : {
              "hits" : {
                "total" : 11603,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMKILjo3PexoUulA",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:16:31.781 +0800 INFO  Metrics - group=thruput, name=index_thruput, instantaneous_kbps=0.875684, instantaneous_eps=2.032165, average_kbps=0.340430, total_k_processed=33138.000000, kb=27.147461, ev=63.000000"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=,_=,_=",
        "doc_count" : 11417,
        "keyword" : {
          "doc_count" : 11417,
          "buckets" : [ {
            "key" : "qwork_units",
            "doc_count" : 11417,
            "score" : 31.50372251905054,
            "bg_count" : 11417,
            "hit" : {
              "hits" : {
                "total" : 11417,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMLOLjo3PexoUunn",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:15:29.777 +0800 INFO  Metrics - group=tpool, name=indexertpool, qsize=0, workers=2, qwork_units=0"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=---,_=.,_=,_=",
        "doc_count" : 11350,
        "keyword" : {
          "doc_count" : 11350,
          "buckets" : [ {
            "key" : "generic",
            "doc_count" : 11350,
            "score" : 31.69559471365639,
            "bg_count" : 11350,
            "hit" : {
              "hits" : {
                "total" : 11350,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUukk",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:02.779 +0800 INFO  Metrics - group=pipeline, name=indexerpipe, processor=syslog-output-generic-processor, cpu_seconds=0.000000, executes=104, cumulative_hits=161564"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=,_=.",
        "doc_count" : 7135,
        "keyword" : {
          "doc_count" : 7135,
          "buckets" : [ {
            "key" : "search_health_metrics",
            "doc_count" : 7135,
            "score" : 51.010511562718996,
            "bg_count" : 7135,
            "hit" : {
              "hits" : {
                "total" : 7135,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUujq",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:33.776 +0800 INFO  Metrics - group=search_health_metrics, name=bundle_directory_reaper, bundle_dir_reaper_max_ms=1, bundle_dir_reaper_mean_ms=1.000000"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=,_=.,_=,_=,_=,_=",
        "doc_count" : 5849,
        "keyword" : {
          "doc_count" : 5849,
          "buckets" : [ {
            "key" : "search_queue_metrics",
            "doc_count" : 5849,
            "score" : 62.445888186014706,
            "bg_count" : 5849,
            "hit" : {
              "hits" : {
                "total" : 5849,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMKILjo3PexoUulx",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:16:31.777 +0800 INFO  Metrics - group=search_concurrency, name=search_queue_metrics, enqueue_seaches_count=0, avg_time_spent_in_queue=0.000000, max_time_spent_in_queue=0, current_queue_size=0, largest_queue_size=0, min_queue_size=0"
                  }
                } ]
              }
            }
          } ]
        }
      }, {
        "key" : "--_::._+____-_=,_=,_=,_=,_=,_=,_=,_=,_=,_=,_=,_=,_",
        "doc_count" : 5848,
        "keyword" : {
          "doc_count" : 5848,
          "buckets" : [ {
            "key" : "max_ready",
            "doc_count" : 5848,
            "score" : 62.45673734610123,
            "bg_count" : 5848,
            "hit" : {
              "hits" : {
                "total" : 5848,
                "max_score" : 1.0,
                "hits" : [ {
                  "_index" : "logstash-2016.07.18",
                  "_type" : "logs",
                  "_id" : "AVX-RMJbLjo3PexoUuk5",
                  "_score" : 1.0,
                  "_source" : {
                    "message" : "07-15-2016 14:17:02.776 +0800 INFO  Metrics - group=searchscheduler, dispatched=1, skipped=0, total_lag=1, max_ready=0, max_pending=0, max_lag=1, window_max_lag=0, window_total_lag=0, max_running=0, actions_triggered=0, completed=1, total_runtime=0.189, max_runtime=0.189"
                  }
                } ]
              }
            }
          } ]
        }
      } ]
    }
  }
}
```

响应体中可以看到因为 `terminate_after` 设得还是过大，所以还没到中止条数就被 kill 了。实际只扫描了 370173 条数据。那么我们下次就可以把 `terminate_after` 调成 10000 得了。

然后就是 `significant_terms` 返回的关键词们。跟之前 splunk 的截图相比，我们可以发现，不是完全一样的效果，但是还是有部分关键词是一致的。比如 `smallest_size`, `total_k_processed`, `search_health_metrics`, `var`, `workers` 等。

可以说，作为一个山寨品，这个做法是行得通的~

