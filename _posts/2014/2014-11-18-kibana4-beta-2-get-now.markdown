---
layout: post
theme:
  name: twitter
title: 【翻译】Kibana 4 beta 2 发布
category: logstash
tags:
  - kibana
---

原文地址见：<http://www.elasticsearch.org/blog/kibana-4-beta-2-get-now/>

---------------------

哈哈哈哈哈哈哈哈哈！来啦！Kibana 4 Beta 2 现在正式雪地 360° 裸跪求调戏，包括你家喵星人都行，只要你给反馈。(译者注：ES 的发版日志越来越活泼，我也翻译的更中文化点好了)

如果你已经等不及要开动，从[这里](http://www.elasticsearch.org/overview/kibana/installation/)下载 Kibana 4 Beta 2，否则继续阅读下面的亮点。

除了很多小的修复和改进，这个版本里还有一些非常值得一看的新东西：

## 地图支持

地图回来啦，而且比过去更强大了！新的瓦片式地图可视化用上了 Elasticsearch 强大的 `geohash_grid` 来显示地理数据，比如可视化展示相对响应时间：

![map](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-3.20.00-PM-1024x547.png)

## 可视化选项

在 Beta 1 里，柱状图是固定成堆叠式的。在 Kibana 4 Beta 2 里，我们添加了选项让你修改可视化展示数据的方式。比如，分组柱状图：

![grouped bars](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-3.15.56-PM-1024x564.png)

或者百分比式柱状图：

![Percent bars](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-4.02.57-PM-1024x537.png)

## 区域图

Beta 2 里区域图也回来了，包括堆叠式和非堆叠式：

![area](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-3.13.21-PM-1024x564.png)

## 高级参数

我们目标是支持尽可能多的 Elasticsearch 特性，不过有时候我们确实还没覆盖到某个聚合选项，而你偏偏现在就要用它。这种情况下，我们引入了 JSON 输入，让你可以定义附加的聚合参数到发送的请求里。比如，你可能想在一个 `terms` 聚合里传递一个 `shard_size`，或者在一个基数聚合里调大 `precision_threshold`。在下面示例中，我们传了一个小脚本作为高级参数，计算 `bytes` 字段的 `_value` 的对数值，然后用它作为 X 轴：

![scripts](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-3.41.13-PM-1024x538.png)

## 数据表格

有时候你想要个动态图，有时候可能只想要数值就够了。数据表格可视化达成你这个愿望：

![data table](http://www.elasticsearch.org/content/uploads/2014/11/Screen-Shot-2014-11-10-at-3.45.02-PM-1024x536.png)

## 喂！我的仪表盘哪去了？

Kibana 内部使用的索引从 `kibana-int` 改名叫 `.kibana` 了。我们建议你从老索引里把文档(比如：仪表盘，设置，可视化等)都挪到新索引来。不过，你还是可以在 kibana.yml 里直接定义 `kibanaIndex: "kibana-int"` 的。

## 我们现在在做什么？

可以从 [roadmap](https://github.com/elasticsearch/kibana/labels/roadmap) 上看到我们离 Kibana 4 正式版还有多远。另外，我们永远欢迎你在 [GitHub](https://github.com/elasticsearch/kibana/issues) 的反馈、bug 报告、补丁等等。
