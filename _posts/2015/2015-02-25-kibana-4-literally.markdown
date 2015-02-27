---
layout: post
title: 【翻译】kibana 4 正式就位
category: logstash
tags:
  - kibana
---

原文地址：<http://www.elasticsearch.org/blog/kibana-4-literally/>

Kibana 4 现在，从内到外，从前到后，从唯心到唯物，全方位的，正式达到产品级就绪状态了。好吧，其实一个星期前就准备好了，不过我们希望达到绝对的确保它没问题。现在，我们可以分享这个开心的消息给大家了：Kibana 4.0.0 GA 啦！截图和主要信息见下。如果你也如此激动，我们给你准备好了两步计划：

1. 从 [Kibana 4 下载](http://www.elasticsearch.org/overview/kibana/installation/)页获取它；
2. 阅读 [Kibana 4 文档](http://www.elasticsearch.org/guide/en/kibana/current/index.html) 掌握它。

小贴士: 如果你还没准备好，你需要先升级你的集群到 [Elasticsearch 1.4.4](http://www.elasticsearch.org/downloads/1-4-4/)

小贴士 2: 如果你是从 Kibana4 RC1 升级上来，你需要迁移一下你的配置。[迁移方式见 gist 链接](https://gist.github.com/spalger/8daf6c2b7f2954639e38)

**背后的故事**

Kibana 一直是用来解决问题的工具。为什么我每天半夜 2 点要被喊起来？代码什么时候推送到生产环境了？它是不是破坏什么了？嗯，我们解决的就是这些。多年以来，不止一个人被凌晨 2 点喊起来。我知道的，对吧？

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-17-at-1.25.15-PM-1024x692.png)

通常的说，答案越简单的时候，问题其实越难。现在，让我们来解决这个难题，这个问题有三层。解决这个问题，需要分析多个维度，多个字段，多个数据源。Kibana 4 正是我们努力创造来用最短时间和最小的麻烦解决最难的问题的。

我们从 Kibana 3 里学到的东西，都应用到了 Kibana 4 里。为什么满足于在地图上画 1000 个点，而实际上我们可以有一亿个点？为什么满足于一个图上处理一个字段？或者一个面板上一个图？为什么一个仪表板上只能一个索引？让我们生成 5 个场景，跨越 2 个字段对比数据，然后从 3 个索引里读取这些数据，放到一个仪表板里。好，让我们开始，然后就可以吃冰淇淋去了。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-17-at-1.24.14-PM-1024x624.png)

**绘图**

就像冰淇淋一样，问题也有很多风格。为此，我们把 Kibana 划分成那不勒斯风格，但愿不是你讨厌的风格。如果你是 Kibana 的长期用户，你会在主页的第一个标签 Discover 页上感受到亲切。这页让你快速搜索，查找记录，以解决哪些可以通过单条记录讲清全部故事的简单问题。

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-17-at-1.55.18-PM1-1024x573.png)

当事情复杂到简单的搜索无能为力的时候，就需要图表来发挥魔力了。切换到 Visualize 标签，用 Elasticsearch 的聚合来分解数据。Visualize 展开数据的多个维度，让你构建图形、表格、地图，来快速解答哪些你之前从来不知道怎么回答的问题。你首先可能被问到的问题应该是“为什么网站上星期变慢了？”，但是这个问题通过数据显示，其实应该是“为什么圣诞节的时候东京地区的请求平均文件大小陡增了？”

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-18-at-11.13.37-AM-1024x617.png)

最后，把这些合一起放到 Dashboard 上。放到一个大屏幕上然后说：“这是你要的答案，这里有个链接可以以后用。同样，我会写到 wiki 里，把数据导出成 CSV 然后发邮件给你。刚吃了点冰淇淋然后写了我简历的第一节。现在给我送更多的冰淇淋来，我吃完了。”

![](http://www.elasticsearch.org/content/uploads/2015/02/Screen-Shot-2015-02-17-at-3.30.30-PM-1024x715.png)

每个标签的细节，请阅读 [Kibana 4 Beta 1: Released](http://chenlinux.com/2014/10/07/kibana-4-beta-1-released/) 博文。

**后续…**

现在可以睡会儿了么？当然不。Kibana 4.1 已经在开发中，我们对未来还有着大计划呢。很多变更在努力让 Kibana 4 更稳定和智能，让我们有一个平台，来构建未来的 Elasticsearch 应用。一切都被设计成可扩展的。比如，可视化部分就可以在它的基础上再构建。开源不仅仅是一个 GitHub 账号，而是我们的一个承诺，让每个人都能在我们的结构上构建创新产品。

阅读[我们的开发者博客](http://www.elasticsearch.org/blog)里的文章，构建你自己的 Kibana 可视化，创建你自己的 Elasticsearch 应用。想要先睹为快？看 Spencer Alger 在 [Elastic{ON}15](http://www.elasticon.com/) 上的演讲吧。

没有你们就没有我们的现在！所以，还是那句话，到 [GitHub](https://github.com/elasticsearch/kibana) 上给我们提问题，建议，贡献。或者，如果你跟我们一样喜欢 IRC，加入我们在 Freenode 上的 #kibana 频道。

**额外的话**

想了解整个 Kibana 4 故事？阅读之前有关 Kibana 4 beta 的博文：

* [Kibana 4 Beta 1: Released](http://chenlinux.com/2014/10/07/kibana-4-beta-1-released/)
* [Kibana 4 Beta 2: Get it now](http://chenlinux.com/2014/11/18/kibana-4-beta-2-get-now/)
* [Kibana 4 Beta 3: Now more filtery](http://chenlinux.com/2014/12/19/kibana-4-beta-3-now-more-filtery/)
* [Kibana 4 RC1: Freshly baked](http://chenlinux.com/2015/02/25/kibana-4-rc1-is-now-available/)

最后，如果你觉得自己有关于 Kibana 的好故事，我们很乐意倾听。发邮件到 [stories@elasticsearch.com](stories@elasticsearch.com) 或者 [在 Twitter](http://www.twitter.com/elasticsearch) 上联系，我们会帮你分享成功的喜悦给全世界！
