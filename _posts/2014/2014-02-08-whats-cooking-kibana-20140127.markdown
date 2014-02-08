---
layout: post
title: 【翻译】Kibana 发生什么事了？
category: logstash
tags:
  - kibana
---

注：本文是 Elasticsearch 官方博客 2014 年 1 月 27 日《what’s cooking in kibana》的翻译，原文地址见：<http://www.elasticsearch.org/blog/whats-cooking-kibana/>

-----------------------------------------------

Elasticsearch 1.0 即将发布， Kibana 团队也准备发布自己的新版。除了一些常见的 bug 修复和小调整，下一个版本中还有一些超棒的特性：

面板组
==============

面板现在可以组织成组的形式，组内可以容纳你乐意加入的任意多的面板。每行的删减都很干净，隐藏面板也不会消耗任何资源。

![](http://www.elasticsearch.org/content/uploads/2014/01/rows_as_groups.png)

图表标记
=============

变更部署，用户登录以及其他危险性事件导致的流量、内存消耗或者平均负载的变动，图表标记让你可以输入自定义的查询来将这些重要事件标记到时间轴图表上。

![](http://www.elasticsearch.org/content/uploads/2014/01/chart_markers.png)

即时过滤器
==============

创建你自己的请求过滤器然后保存下来以备后用。过滤器将和仪表盘一起保存，而且可以在对比你定义的数据子集的时候菜单式展开或收缩。

![](http://www.elasticsearch.org/content/uploads/2014/01/adhoc_filters.png)

top-n 查询
================

单击某个查询旁边的带色的点，就可以设置这个查询的颜色。新版的top-N 查询会找出一个字段 最流行的结果，然后用他们来完成新的查询。

![](http://www.elasticsearch.org/content/uploads/2014/01/top_n_queries.png)

stats 面板
==============

Stats 面板最后都将把搜索归总成一个单独的有意义的数值。

![](http://www.elasticsearch.org/content/uploads/2014/01/stats_panel.png)

terms_stats 模式
=================

按国家统计流量？每个用户的收入？每页的内存使用？terms面板的terms_stat模式正是你想要的。

![](http://www.elasticsearch.org/content/uploads/2014/01/Screen-Shot-2014-01-27-at-9.14.42-AM.png)

