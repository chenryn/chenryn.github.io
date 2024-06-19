---
layout: post
theme:
  name: twitter
title: 【翻译】Kibana 3 升级到 4 的常见问答
category: logstash
tags:
  - kibana
---

原文见<https://github.com/elasticsearch/kibana/blob/master/K3_FAQ.md>。

问：我在 Kibana 3 里最想要的某某特性有了么？
答：就会有了！我们已经以 ticket 形式发布了目前的 roadmap。查看 GitHub 上的 beta 里程碑，看看有没有你想要的特性。

问：仪表板模式是否兼容？
答：不好意思，不兼容了。要创建我们想要的新特性，还是用原先的模式是不可能的。Aggregation 跟 Facet 请求从根本上工作方式就不一样，新的仪表板不再绑定成行和列的样式，而且搜索框，可视化和仪表板的关系过于复杂，我们不得不重新设计一遍，来保证它的灵活可用。

问：怎么做多项搜索？
答："filters" Aggregation 可以运行你输入多项搜索条件然后完成可视化。甚至你可以在这里面自己写 JSON。

问：模板化/脚本化仪表板还在么？
答：看看 URL 吧。每个应用的状态都记录在那里面，包括所有的过滤器，搜索和列。现在构建脚本化仪表板比过去简单多了。URL 是采用 RISON 编码的。

### 译者注：

RISON 是一个跟 JSON 很类似，还节省不少长度的东西。其官网见：<http://mjtemplate.org/examples/rison.html>。但是我访问看似乎已经挂了，更多一点的说明可以看<https://github.com/Nanonid/rison>。

