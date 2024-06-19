---
layout: post
theme:
  name: twitter
title: 【翻译】kibana发生什么变化了？
category: logstash
tags:
  - elasticsearch
  - kibana
---

本文来自Elasticsearch官方博客，2013年8月21日的文章[kibana: what’s cooking](http://www.elasticsearch.org/blog/kibana-whats-cooking/)，作为kibana3重要的使用说明，翻译如下：

还没有升级Kibana么？那你可错过了一个好技术！Kibana 发生了翻天覆地的变化，新面板只是这个故事中的一部分。整个系统都被重构，给表盘提供统一的颜色和图例方案选择。接口也经过了标准化，很多函数都修改成提供更简单，快速和功能更强大的方式。让我们进一步看看现在的样子。

![](http://www.elasticsearch.org/content/uploads/2013/08/BQIielHCAAAs2So.png)

Terms 面板；全局色彩；别名和查询；过滤器。

新的查询输入
=============

新的查询面板替代了原来的“字符串查询”面板作为你输入查询的方式。每个面板都有自己独立的请求输入。你也还可以为特殊的面板定制请求，不过你要先在这里输入他们，包括可以有别名和颜色设置，然后再在面板编辑器里选取。在没有被激活修改的时候， 查询也可以被固定在一个可折叠的区域。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-08-20-at-11.48.43-AM.png)

分配查询到具体面板
====================

分配查询到具体面板非常非常简单。面板编辑器里就可以直接打开或关闭查询，哪怕这个查询已经更新或者过滤掉，它的别名是保持全局一致性的。你还会注意到配置窗口被分割成了选项卡形式，已提供更清晰的配置界面。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-08-20-at-1.34.08-PM.png)

自定义颜色和别名
==================

当你给一个查询分配某个颜色的时候，它会立刻反映到所有的面板上。通常用于做图例值的别名也一样。这样，我们可以很简单的通过在一个逻辑组里分配颜色变化，调节整个仪表盘和数据的意义。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-07-11-at-5.00.28-PM.png)

你好，terms!
===================

引入了一个新的terms面板，可以使用3种不同的格式展示顶层字段数据：饼图、柱状图和表格。而且都可以点击进入新的过滤器面板。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-08-20-at-1.47.56-PM.png)

过滤器面板?
==============

刚刚提到过滤器面板，对吧？没错，过滤器！过滤器允许你深入分解数据集而不用你去修改查询本身。然后，过滤器也可以被删除、隐藏和编辑。过滤器有三种模式：

* __must__: 记录必须匹配这个过滤器；
* __mustNot__: 记录必须不能匹配这个过滤器；
* __either__: 记录必须匹配这些过滤器中的一个。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-08-20-at-1.55.54-PM.png)

字段列表和微面板
=================

字段面板集成在表格面板里。字段列表现在会通过访问Elasticsearch的`/_mapping`API来自动填充。注意你可能需要更新自己的代理服务器配置来适应这个变更。为了节约空间，这个字段列表现在也是可折叠的，而新的图形也添加到了微面板。

![](http://www.elasticsearch.org/content/uploads/2013/08/Screen-Shot-2013-08-20-at-7.56.02-AM.png)

嗨，那配色方案呢?!
==================

对，你在我解释之前已经发现这个变化了！Kibana现在允许你在黑白两个配色方案之间切换以刚好的匹配你自己的环境和偏好。

![](http://www.elasticsearch.org/content/uploads/2013/08/BQjv-50CcAAyazu.png)

汇报完毕！当然kibana一直在更新，注意继续关注这里，给我们的[github项目](https://github.com/elasticsearch/kibana/)加星，然后上推特fo [@rashidkpc](https://twitter.com/rashidkpc/) 和 [@elasticsearch](https://twitter.com/elasticsearch/)。
