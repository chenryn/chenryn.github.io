---
layout: post
title: 【翻译】Kibana 4 RC1 发布
category: logstash
tags:
  - kibana
---

原文地址：<http://www.elasticsearch.org/blog/kibana-4-rc1-is-now-available>

Kibana 4 的第一个 RC 版带着可选色、可堆叠、柱状图、饼图等等来啦！你应该注意到标题里的字母了，没错，现在不再是 beta 了。这意味着什么？这意味着我们打磨好了毛边，擦干净了痕迹。也意味着更加稳定，更好的性能，以及一些新的特性。

The good stuff is below, but if you want to jump right in then upgrade to Elasticsearch 1.4.3 and grab the new build over on the [Kibana 4 download page](http://www.elasticsearch.org/overview/kibana/installation/) right away.

**小贴士**

1. 建议升级到 Elasticsearch 1.4.3。 Kibana 4 RC1 依赖一些 Elasticsearch 1.4.3 的功能。
2. 更新你的 `kibana.yml`，有些配置参数发生了变化，比如 `elasticsearch` 现在叫 `elasticsearch_url`。

## 多序列图

Kibana 4 现在支持在每个图上画多个数值聚合。比如，在一个图上显示一个字段，或者完全不相关的多个字段的最小、最大和平均值。我们还添加上了呼声很高的百分比聚合，以及标准差视图。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-11-at-4.47.29-PM-1024x572.png)

## 部分数据桶的标示

你可能注意到过，很多分析引擎的最后一个点上，数据总是下降的。这是因为最后一个条带本身“没满”。比如一个每天的条带图，但是今天还没结束呢。Kibana 现在会给你展示这一天还有多少剩余时间，通过一个微妙的阴影设计，表示还有后续的时间序列数据。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-10-at-8.20.44-AM-1024x573.png)

## 仪表板上的文档表格

作为可视化的补充，Kibana 现在也可以在仪表板上展示已存的搜索了。和添加可视化内容一样操作，不过注意这个 “Searches” 标签。Kibana 会加载你保存的搜索，包括它的各列内容，然后排序列入仪表板上的表格。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-11-at-4.53.55-PM-1024x633.png)

## markdown 挂件和表格过滤器

是不是厌烦饿了回答这个问题：“这行是啥意思？”。markdown 挂件让你可以给复杂的仪表板添加帮助信息面板。而且，数据表格现在跟其他面板一样也支持点击生成过滤器的功能了。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-11-at-9.13.34-PM-1024x677.png)

## 脚本化字段上的过滤器

Beta 3 不允许在脚本上做过滤。RC 现在通过透明传输的方式支持了 Elasticsearch 的 script filter 功能。在脚本化字段上点击生成过滤器，就跟普通字段一样。

Kibana 4 RC1 同时还从 Groovy 迁移到了 [Lucene Expressions](http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/modules-scripting.html#_lucene_expressions_scripts)，这个变化出自 Elasticsearch 1.4.3 版的变更。因为 Lucene expressions 目前只支持数值类型的数据和函数，我们正在努力，早日支持字符串、时间类型。

## 自动刷新

自动刷新回来了！它使用和 Kibana 其他地方用的面板刷新一样的请求系统，所以，它也可以在各处正常工作，包括 Discover，Visualize 和 Dashboard。

## nodejs 后端

我们把后端实现从 Java(具体地说是 JRuby) 迁移到了更新，更快，兼容性更好的 NodeJS。不要担心，我们会打包好 NodeJS 和 Kibana 在一起，没有 Java 依赖的安装步骤会更简单了。启动命令还是那样： `./bin/kibana`，而且启动几乎是即时完成！

另一方面，你需要为你的操作系统选择正确的包下载地址。作为操作系统分发版有区别这个事情的补偿(虽然其实毫不相干)，我们免费开放了 SSL 支持功能，不管是从浏览器发出的还是发送去 Elasticsearch 的。

## 更多

好了，牛排上来了开吃。不，其实还没，我们还带来了可配置格式的 CSV 导出，更好的数字处理和一个新的页面风格。谁知道我们还藏了什么呢？或许有？或许没有？唯一的办法就是下载下来你自己找找看；所以，现在就出发吧！一定要抢在别人前面，否则就没你的份了！

最后还是那句话，到 [GitHub](https://github.com/elasticsearch/kibana) 上给我们提问题，建议，贡献。或者，如果你跟我们一样喜欢 IRC，加入我们在 Freenode 上的 #kibana 频道。
