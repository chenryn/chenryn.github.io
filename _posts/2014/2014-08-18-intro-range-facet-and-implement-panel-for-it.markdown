---
layout: post
theme:
  name: twitter
title: 用 ES 的 RangeFacets 接口实现一个查看区间占比的 Kibana 面板
category: logstash
tags:
  - kibana
  - elasticsearch
  - javascript
---

公司用 kibana 的同事提出一个需求，希望查看响应时间在不同区间内占比的饼图。第一想法是用 1.3.0 新加的 percentile rank aggregation 接口。不过仔细想想，其实并不合适 —— 这个接口目的是计算固定的 `[0 TO $value]` 的比例。不同的区间反而还得自己做减法来计算。稍微查了一下，更适合的做法是专门的 range aggregation。考虑到 kibana 内大多数还是用 facet 接口，这里也沿用：<http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-facets-range-facet.html>。

range facet 本身的使用非常简单，就像官网示例那样，直接 curl 命令就可以完成调试：

```
curl -XPOST http://localhost:9200/logstash-2014.08.18/_search?pretty=1 -d '{
    "query" : {
        "match_all" : {}
    },
    "facets" : {
        "range1" : {
            "range" : {
                "field" : "resp_ms",
                "ranges" : [
                    { "to" : 100 },
                    { "from" : 101, "to" : 500 },
                    { "from" : 500 }
                ]
            }
        }
    }
}'
```

不过在 kibana 里，我们就不要再自己拼 JSON 发请求了 —— 虽然之前我实现 percentile panel 的时候就是这么做的 —— 前两天合并了 github 上一个 commit 后，现在可以用高版本的 elastic.js 了，所以我也把原来用原生 `$http.post` 方法写的 percentile panel 用 elastic.js 对象重写了。

elastic.js 关于 range facet 的文档见：<http://docs.fullscale.co/elasticjs/ejs.RangeFacet.html>

因为 range facet 本身比较简单，所以 RangeFacet 对象支持的方法也比较少。一个 `addRange` 方法添加 ranges 数组，一个 `field` 方法添加 field 名称，就没了。

所以这个新 panel 的实现，更复杂的地方在如何让 range 范围值支持自定义填写。这一部分借鉴了同样是前两天合并的 github 上另一个第三方面板 multifieldhistogram 的写法。

另一个需要注意的地方是饼图出来以后，单击饼图区域，自动生成的 `filterSrv` 内容。一般的面板这里都是 `terms` 类型的 `filterSrv`，传递的是面板的 label 值。而我们这里 label 值显然不是 ES 有效的 terms 语法，还好 `filterSrv` 有 `range` 类型(histogram 面板的 `time` 类型的 `filterSrv` 是在 daterange 基础上实现的)，所以稍微修改就可以了。

最终效果如下：

![](https://github.com/chenryn/kibana/raw/master/src/img/chenryn_img/range-panel.jpg)

面板的属性界面如下：

![](https://github.com/chenryn/kibana/raw/master/src/img/chenryn_img/range-setting.jpg)

代码已经上传到我个人 fork 的 kibana 项目里：<https://github.com/chenryn/kibana.git>

*我这个 kibana 里已经综合了 8 个第三方面板或重要修改。在官方年底推出 4.0 版本之间，自觉还是值得推荐给大家用的。具体修改说明和效果图见 README。*
