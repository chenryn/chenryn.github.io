---
layout: post
title: Kibana 中几个不同的 filtering
category: logstash
tags:
  - elasticsearch
  - kibana
---

用过 kibana 的都知道，kibana 的图表上，可以直接点击某个值，就能自动添加这个过滤条件到 filtering 里，然后整个 dashboard 上所有的图表都会刷新成在这个过滤条件下的新状态。但是如果你要想自己手动添加 filtering 的时候，就会发现，自己添加的，写法好像跟自动生成的长得不太一样。

而今天，我在同事的提醒下，发现更进一步的情况，即使都是通过点击图表添加上的 filtering，其实长得也不一样，如下图：

![](/images/uploads/filterings.png)

* 在 histogram 面板上拖拽鼠标，生成的是 range filtering
* 在 terms 面板上点击某个值，生成的是 term filtering
* 在 table 面板左侧列表上点击某个字段，浮出的小面板里点击某个值，生成的是 query filtering
* 在 filtering 手工添加，生成的是 query_string filtering

这几个页面上的不同，反应在实际的请求 JSON 里又有什么区别呢？

我们可以点开面板右上角的 inspect 按钮看生成的 curl 命令。其中 filtering 部分如下：

```json
    "filter": {
      "bool": {
        "must": [
          {
            "range": {
              "@timestamp": {
                "from": 1418009781101,
                "to": "now"
              }
            }
          },
          {
            "terms": {
              "_type": [
                "mweibo_webinf"
              ]
            }
          },
          {
            "fquery": {
              "query": {
                "query_string": {
                  "query": "host:(\"web093.mweibo.tc.sinanode.com\")"
                }
              },
              "_cache": true
            }
          },
          {
            "fquery": {
              "query": {
                "query_string": {
                  "query": "host:\"web093.mweibo.tc.sinanode.com\""
                }
              },
              "_cache": true
            }
          }
        ]
      }
    }
```

前面两个不出意外，都是很标准的 api 示例的样子。比较特殊的是后面两个：

第三个其实就是通过 table 左侧字段菜单点出来的，虽然通过鼠标点击操作，只可能生成一个单一的键值查询，但这里却给加上了一对小括号！这是完全没有必要的，简直可以怀疑是不是当初开发人员手抖了……

当然，并不是说这种生成完全没有用。比方说，其实你本来是打算查询来自两台机器的日志。如果没想到用括号，可能直接在 query_string 里就写 `host:"web001" OR host:"web002"` 了。但是在这个 query filtering 里，因为页面上已经有单独填字段的地方了。那就只用在 query 那栏写 `"web001" OR "web002"` 好了。

以上。不过我依然怀疑是开发人员手抖。
