---
layout: post
theme:
  name: twitter
title: 【翻译】Kibana 4 beta 3 发布，重新支持过滤器
category: logstash
tags:
 - kibana
---

本文是 Elasticsearch 官方博客内容，原文地址：<http://www.elasticsearch.org/blog/kibana-4-beta-3-now-more-filtery/>

---------------------

Kibana 4 Beta 3 出来啦! 我们依然给你机会直接[下载 Kibana 4 Beta 3](http://www.elasticsearch.org/overview/kibana/installation/)。不过还是要建议你阅读本文对主要特性的讲解。嗯，先暂停一下下载，开始阅读吧！

## 交互式图表和仪表盘

过滤器回到了仪表盘上，也可以在单个可视化页上使用了！柱状图、点图、饼图都可以通过点击的方式创建可切换的过滤器。我们还添加了一些函数来操作所有的过滤器，这样你可以一键切换整个过滤效果。

![Screen Shot 2014-12-15 at 12.28.30 PM](http://www.elasticsearch.org/content/uploads/2014/12/Screen-Shot-2014-12-15-at-12.28.30-PM-1024x693.png)

## 脚本化字段

Kibana 现在支持 Elasticsearch 脚本了！不单是可以写脚本，还可以给它命名，并且在应用中跟用普通字段一样调用你取的名字。创建一个脚本化字段，这个字段就像本来就存在一样的显示在你的 Kibana 文档里了。唯一需要注意的是，脚本毕竟不是 Elasticsearch 索引的内容，你不能在这个字段里进行搜索。

你可以用脚本来连接多个字段，或者在数值字段上做运算，然后把结果导入可视化页里。为了帮助你上手，我们在脚本化字段屏下添加了一个标题叫“从时间字段创建的示例”的连接。你可以在设置(Settings)标签页的索引(Index)区域里找到这个连接。选择或者创建一个索引表达式，然后点击“脚本化字段(Scripted Fields)”标签。

![Screen Shot 2014-12-15 at 1.06.51 PM](http://www.elasticsearch.org/content/uploads/2014/12/Screen-Shot-2014-12-15-at-1.06.51-PM.png)

做完这些以后，你就可以在聚合页里找到一些新的数值字段可用。比如说，我们可以查一天的 24 个小时，然后获取 30 天 来每个小时的 hits 数的总和：

![unnamed](http://www.elasticsearch.org/content/uploads/2014/12/unnamed.png)

## 高亮和 _source 的新格式

JSON 很棒，我们都爱 JSON。谁会不爱 JSON 呢？XML，这是谁？完全无关紧要嘛。

JSON 在查看上可能有点乱，所以我们对格式做了一点优化。原始的 JSON 内容，当然可以在点击 JSON 标签展开事件后查看。Kibana 现在还会自动高亮匹配上的字段，甚至把他们挪到本行开头的位置展示：

![Screen Shot 2014-12-16 at 11.16.17 AM](http://www.elasticsearch.org/content/uploads/2014/12/Screen-Shot-2014-12-16-at-11.16.17-AM-1024x730.png)

## hit 连接

可能你已经注意到前面截屏上的 “Link to..” ? 你可能不需要分享整个可视化结果或者一个搜索结果，你只是想让别人看到一条重要的命中的记录。现在，这事儿简单了！

## metric visualization

有时候你不需要图或者文档！你只需要一个数值在仪表盘上就够了。现在可以做到了：

![Screen Shot 2014-12-16 at 11.16.59 AM](http://www.elasticsearch.org/content/uploads/2014/12/Screen-Shot-2014-12-16-at-11.16.59-AM.png)

好了，就是这些！还是那句话，到 [GitHub](https://github.com/elasticsearch/kibana) 上给我们提问题，建议，贡献。或者，如果你跟我们一样喜欢 IRC，加入我们在 Freenode 上的 #kibana 频道。
