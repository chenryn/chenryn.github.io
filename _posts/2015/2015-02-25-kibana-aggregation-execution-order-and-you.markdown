---
layout: post
title: 【翻译】kibana 的聚合执行次序
category: logstash
tags:
  - kibana
  - elasticsearch
---

原文地址：<http://www.elasticsearch.org/blog/kibana-aggregation-execution-order-and-you/>

可能现在你已经发现了 Kibana 4 的 Visualize 界面上那些狡猾的小箭头，然后会问：“你们在那干嘛呢？有啥用啊？”嗯，这些按钮是用来控制聚合执行次序的。这个就定义了 Elasticsearch 如何分析你的数据，以及 Kibana 如何展示结果。

![](http://www.elasticsearch.org/content/uploads/2015/02/crafty_arrows.png)

让我们预设一个常见的场景：按时序查找最活跃的用户。很简单对吧？没错，不过其实你的需求并不明确，目的并不清楚。什么叫“最活跃的用户”？让我们多加几个参数：一年时间，按照每周，计算前 5 名用户。现在更接近结果了，不过我们还是有两条不同的方式来解释这个需求：

1. 一年时间内的前 5 名用户，他们的每周活跃度
2. 每周的前 5 名用户，持续统计一年

## 每周的前 5 名用户，持续统计一年

这个截屏里，我们先运行时间轴柱状图(date histogram)，然后再问前 5 名用户。这就会给一年的每个星期创建一个桶(bucket，译者注：ES 的 聚合 API 响应内容就是以 bucket 存在的)。在每个星期里，我们找到前 5 名用户，所以在这种情况下，每周的前 5 名用户，可能都是不一样的，最后在图例里，你就看到超过 5 个用户了。

然后，如果我们点开阴影区域的聚合请求(Request)标签，可以看到，date histogram 是先请求的，在 date histogram 里再加上了 terms 的聚合。结果就是我们看到有些星期某些用户异常活跃，而他们可能在其他时候毫无动静。这样我们就找到指定星期里的离群数据了。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-19-at-4.12.38-PM-1024x751.png)

## 一年时间内的前 5 名用户，他们的每周活跃度

现在，我们点击向上箭头，把 terms 聚合移到 date histogram 上面来。现在我们是先计算整年的前 5 名用户，然后给每个用户创建一个 date histogram。这下图例里就只有 5 个值了。不过，我们现在看到的用户也是持续活跃的，不再有离群数据了。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-19-at-4.12.55-PM-1024x750.png)

## 总结

所以现在你知道了：这些箭头还是有用的。聚合执行次序应用于 Kibana 里几乎所有的图，所以显著影响着你在图上看到的数据，以及你从数据得出的结论。

最后，如果你觉得自己有关于 Kibana 的好故事，我们很乐意倾听。发邮件到 [stories@elasticsearch.com](stories@elasticsearch.com) 或者 [在 Twitter](http://www.twitter.com/elasticsearch) 上联系，我们会帮你分享成功的喜悦给全世界！
