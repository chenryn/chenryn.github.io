---
layout: post
title: elasticsearch 的 sampler 聚合
category: elasticsearch
tags:
    - elasticsearch
---

在上一篇文章的基础上，其实 Elasticsearch 从 2.0 以后，还新增了另一种聚合方式，叫 sampler。这个聚合的作用，是在每个分片上，只采样部分文档出来继续后续统计。

比如把上一篇的查询改成这样：

```bash
#!/bin/bash
curl -XPOST 'localhost:9200/logstash-2016.07.18/logs/_search?pretty&terminate_after=10000&size=0' -d '
{
    "aggs": {
        "group": {
            "terms": {
                "field": "result.punct"
            },
            "aggs": {
                "sample": {
                    "sampler": {
                         "shard_size": 200
                     },
                    "aggs": {
                        "keyword": {
                            "significant_terms": {
                                "size": 1,
                                "field": "result._raw"
                            },
                            "aggs": {
                                "hit": {
                                    "top_hits": {
                                        "_source": {
                                            "include": [ "result._raw" ]
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
    }
}
'
```

当然，在这个 raw 日志的情况下，取样意义不是特别到，因为有 `terminate_after` 在，采样本身不会绝对随机。但是对其他 `doc_values` 的字段，采样就有意义了。
