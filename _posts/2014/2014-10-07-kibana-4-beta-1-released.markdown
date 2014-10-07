---
layout: post
title: 【翻译】Kibana 4 beta 1 发版日志
category: logstash
tags:
  - kibana
---

原文地址见：<http://www.elasticsearch.org/blog/kibana-4-beta-1-released/>

---------------------

今天，我们<del>自豪高兴满意控制不住地兴奋过头欣喜若狂</del>相当高兴得给大家分享一下 Kibana 项目的未来，以及 Kibana 4 的第一个 beta 版本。
We’re <del>proud delighted jazzed uncontrollably excited over the top ecstatic</del> pretty darn happy, to share the future of Kibana, and the first beta release of Kibana 4 with you today.

## 我现在就要！快给我！

从[这里](http://www.elasticsearch.org/overview/kibana/installation/)下载，然后看 [README.md](https://github.com/elasticsearch/kibana/blob/master/README.md) 里新的而且更简单的安装流程。当然，你最好还是读一下本文剩下的内容，有很多超棒的秘诀呢！

## 欢迎来到 kibana 4

我们正走在 Kibana 4 的漫漫长路上：可以预见还会有好几个 beta 版本，每个都有新的特性，可视化和改善。我们梳理了各种反馈、邮件列表、IRC 以及 Github 的 issue ，把特性加入到这个 beta1 版本中，真是罪孽深重。我们已经在为 beta2 版本努力工作，在此，很高兴分享一下我们的 roadmap，查看 Github 上打有 "[Roadmap](https://github.com/elasticsearch/kibana/issues?q=is%3Aopen+is%3Aissue+label%3Aroadmap)" 标签的 issue。你们的反馈是我们永远做正确的事的保证。

反馈之外，我们回头想了想人们是怎么看数据的，更进一步，人们是怎么解决真实问题的。我们发现一个问题总是能引出另一些问题，而这些问题又能引出更多其他问题。如果你参加了 Monitotama，或者其他 Elasticsearch 见面会，你可能已经看到过 Kibana 4 概念性的原型演示。它可以让你创建更复杂的图标，Kibana 4 从 PoC 出发，扩展出一大堆新特性，让你编写问题，得到解答，然后解决之前从来没这么解决过的问题。

这种组合方式在 Kibana 4 中体现为聚合、搜索、可视化和仪表板融合在一起的方式。为了简化组成，我们把 Kibana 4 分成 3 个不同的界面，虽然一起工作，但是每个负责解决不同的一部分问题。

## 熟悉的界面

如果你是 Kibana 老用户，你会发现主页上 Discover 标签页的样子很熟悉。

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-09-30-at-4.07.15-PM.png)

Discover 功能跟原先的带有一个文档表格和事件时间轴的搜索界面很像。在搜索框里输入，敲回车，然后让 Kibana 去挖掘你的 Elasticsearch 索引。说到索引，有一个快速下拉菜单让你在搜索的时候灵活的在多个索引之间切换。要切换回上一个索引，点击浏览器的回退按钮即可。不喜欢新的搜索关键词？同样点击回退按钮就能返回原来的搜索词了。当然，搜索框的历史中也存着过去的记录。

说道搜索，你既可以输入 Lucene Query String 语法，也可以用上一个经常被要求的特性，**Elasticsearch JSON 搜索** 到搜索框里。我们知道 JSON 格式可能比较难输对，所以不管你输入的是 Lucene Query String 还是 JSON，我们都会在发送给 Elasticsearch 之前替你验证一遍语法。不管你在 Kibana 4 的任何位置输入请求，这点都是生效的。

这样搜索也可以保存下来留待后用。重要的是：搜索不在绑定在仪表板上，他们可以在 Discover 页上再次调用，也可以运用在可能稍后才添加到仪表板上的可视化页里。因为，不管你在仪表板的哪一屏，**搜索一直都会通过 URL 传递**，所以链接到搜索非常简单。

## 画图的在这里

Kibana 4 的 Visualize 标签是之前说的概念原型里最高潮的地方。Kibana 4 把 Elasticsearch 的 nested 聚合函数的威力带到鼠标点击上。比如我想知道哪些国家访问我的网站，什么时候访问的，他们是否登录认证了？通过一个 canvas 上的单一请求，我就可以问出上面这些问题，然后看到结果是怎么相互联系的：

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-2.28.29-PM.png)


Kibana 3 的时候，时间只能在 histogram 面板上显示，而 terms 只能在柱状图上显示。Kibana 4 可以利用多个 **Elasticsearch 聚合函数**。这包括 bucket 和 metric 聚合函数，其中有备受期待的**基数**(又叫唯一计数)聚合函数，更多支持还在实现中。我们不得不创建了一个全新的可视化框架来处理复杂的聚合函数。目前有三种支持的类型：柱状图，线状图和光圈图。同样，更多支持还在实现中。未来每个 Kibana 4 的 beta 版本都值得你期待。

光圈图类似多层次的饼图。理论上它可以有无限的环：

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-12.49.50-PM.png)

柱状图现在还不单单可以做时间。这里我们展示根据文件后缀名分解文件大小范围。

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-1.03.03-PM.png)

现在你可能已经注意到每个可视化页底部的灰色小条。点击它，就可以看到图背后的源数据，然后，在大众要求下，提供了**导出到CSV** 以便后续分析的功能。你还可以看到 Elasticsearch 请求和响应的内容，以及请求的处理耗时。

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-12.31.14-PM.png)

Visualization 既可以互动式搜索创建，让你在建图的时候修改请求，也可以关联到一个之前通过 Discover 标签创建保存的请求上。这样你可以关联一个请求到多个可视化页，如果需要更新一个搜索参数，只需要更新单独一个请求就行了。比如，假设你有多个图表，是用下面语句搜索图片内容的：

```
png OR jpg
```

保存成 "Images"。然后你打算支持动态 GIF 格式，你只需要更新 "Images" 的内容然后保存即可。所有关联了 "Images" 请求的图都会自动应用变更。

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-1.17.08-PM.png)]

## 给我看更多的图！

当然，你依然可以创建令人惊叹的仪表板，而且它们现在更方便创建和管理了。过去那堆凌乱的配置框一去不复返了。添加进仪表板的每个面板都可以在 Visualize 标签页理创建、保存，并且重复利用。就像保存了的搜索可以在多个 visualizations 里使用一样，保存了的 visualization 也可以在多个仪表板里使用。你需要更新一个 visualization 的话，只需要在一个地方修改好，每个仪表板里的都会应用变更。

更进一步，虽然请求和可视化是绑定到一个选定的索引的，仪表板却不用。**一个仪表板可以有从不同索引来的可视化**。这意味着，你可以从你的用户索引关联到网站流量索引，从销售数据关联到市场研究再关联到气象站日志。这些都可以在同一屏上！

![](http://www.elasticsearch.org/content/uploads/2014/10/Screen-Shot-2014-10-01-at-1.19.39-PM.png)

## 更多

一篇博客里完全不够说完全部内容，所以去下载安装然后亲自试试 [HERE](http://www.elasticsearch.org/overview/kibana/installation/) 吧。如果你来自 Kibana 3，我们收集了一个小小的 FAQ 解释：[HERE](https://github.com/elasticsearch/kibana/blob/master/K3_FAQ.md)。还是老话，我们需要你的反馈，构建 Kibana 4 的每一天，我们都用得着这些反馈，而我们也会继续让 Kibana 变得更好，更快，更简单。
