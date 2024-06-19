---
layout: post
theme:
  name: twitter
title: 用 Graphite 存储 Nagios 数据
category: monitor
tags:
  - nagios
  - graphite
  - kibana
---

我们都知道 nagios 上可以用 pnp4nagios 来转换 perfdata 成 rrd 图。不过 graphite 以其扩展性及更好的 HTTP 接口目前越来越受欢迎，加上最近刚出来的 grafana 项目(从 LEK 的 Kibana 转化来的)，更是让 graphite 的可视化效果也上了一个台阶。

那么怎么用 grafana 来查看我们用 nagios 收集来的监控数据呢？

我在 github 上看到有一个叫 graphios 的项目。不过上面介绍的方法已经比较老了，目前 omd 使用的是 npcmod 的 bulk mode，并不会分别产生 `host-perfdata.$TIMET$` 和 `service-perfdata.$TIMET$` 文件。所以照着 README 做是没效果的。

最好的办法就是利用 [Net::Graphite](https://metacpan.org/pod/Net::Graphite) 模块自己改写 `process-perfdata.pl`，把数据直接发给 carbon 进程。不过我懒得动手，目前只是写了几行 perl ，在调用 `process-perfdata.pl` 之前，先过一遍 `perfdata.$TIMET` 文件，分离出来 host 和 service 两个文件放到新目录里，这样就可以继续走通 graphios 的流程了。(当然性能上比较烂，因为磁盘 IO 翻倍了)

然后是 grafana 部分。grafana 本身基于 kibana 改造而来，所以也是一个纯 js 应用，不过请求 graphite 数据可能涉及跨域 ajax，要求 graphite 的 apache 配置加上几个 Header，这个照着 README 做就可以了。然后不要忘了修改 config.js 里对应的 es 和 graphite 两个服务器地址。

graphite 毕竟数据是以 tree 的唯一格式存在，所以在 grafana 上创建图形时的操作跟 kibana 上不太一样。添加 panel 后，默认是空数据的，然后要在 panel正上方的标题上点击鼠标，选择 `edit`，就会出现配置框。

在配置框的 `Metrics` 栏选择 `Add query`，然后 `select metric` 一路选择下去到你想到添加的数值。数值之后点 `+` 号还可以添加一些 graphite 计算的值，像平均数啊之类的。这些可以参考 graphite 接口文档。

![](/images/uploads/add-metric.png)

一个简单的效果图如下：

![](/images/uploads/grafana.png)
