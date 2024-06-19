---
layout: post
theme:
  name: twitter
title: 在 kibana 里实现去重计数
category: logstash
tags:
  - kibana
  - elasticsearch
  - javascript
---

如何在 elk 里统计或者展示去重计数，是一个持续很久的需求了。几乎每个月都会有新手提问题说：“我怎么在 kibana 里统计网站 UV 啊？”可惜这个问题的回答总是：做不到……

其实 Elasticsearch 从 1.1.0 版本开始已经可以做到[去重统计](http://www.elasticsearch.org/blog/count-elasticsearch/)了。但是 kibana3 本身是在 0.90 版本基础上实现的，所以也就没办法了。

今天抽出时间，把 histogram 面板的代码重写了一遍，用 aggregations 接口替换了 facets 接口。改造完成后，再加上去重就很容易了。

aggregations 接口最大的特点是层级关系。不过也不是可以完全随便嵌套的，原先 date_histogram facets 里的 global 参数，被拆分成了 global aggregation，但是这个 global aggregation 就强制要求必须用在顶层。所以最后 request 相关代码就变成了这个样子：

```javascript
var aggr = $scope.ejs.DateHistogramAggregation(q.id);
if($scope.panel.mode === 'count') {
  aggr = aggr.field($scope.panel.time_field);
} else if($scope.panel.mode === 'uniq') {
  aggr = aggr.field($scope.panel.time_field).agg($scope.ejs.CardinalityAggregation(q.id).field($scope.panel.value_field));
} else {
  aggr = aggr.field($scope.panel.time_field).agg($scope.ejs.StatsAggregation(q.id).field($scope.panel.value_field));
}
request = request.agg(
  $scope.ejs.GlobalAggregation(q.id).agg(
    $scope.ejs.FilterAggregation(q.id).filter($scope.ejs.QueryFilter(query)).agg(
      aggr.interval(_interval)
    )
  )
).size($scope.panel.annotate.enable ? $scope.panel.annotate.size : 0);
```

完整的代码已经提交到 github，见 <https://github.com/chenryn/kibana-authorization/commit/6cb4d28a6c610d28680fffdb81c9f6c83cfaf488>
