---
layout: post
theme:
  name: twitter
title: 云原生日志的趋势(2)：logscape和loki
category: logstash
---

上一篇讲logscape和logiq，虽然logscape开源了，但是在开源届其实没掀起什么浪花。开源届在云原生日志方面，目前主要是grafana loki项目引人注目。那这一篇稍微讲讲loki，以及loki和上篇的logscape-ng(fluidity)的设计区别。

## [Grafana Loki](https://grafana.com/oss/loki/)

去年11月的时候，曾经在自己本地小小的测试了一下loki，到目前为止，更新的几个版本的releasenote中，应该没有会明显影响测试结论的改进。

loki的设计思路是：仅用于支持云原生环境下的日志查询需求。所以它建议只对诸如k8s labels、http code之类可枚举的关键查询数据做索引，把日志原文直接压缩存放，要用的时候直接并发grep就行。本地用boltdb，可以写入S3。

所以，测试重点就是两个：

1. 压缩存放的效率。
2. grep查询的效率。

测试采用了日志易内部最常用的2.2GB日志数据集，只是loki要求相同labels下数据导入必须有序，所以得先sort一下。为了对等，也就跟着采用日志易的内置字段appname/tag/hostname/source/logtype作为label。fluentd的导入配置如下：

```
<source>
  @type tail
  path /data/loki/baimi_sorted.log
  pos_file /var/log/td-agent/baimi_sorted.log.pos
  <parse>
    @type json
  </parse>
  time_key timestamp
  tag loki.apache.access
</source>

<match loki.**>
  @type loki
  url "http://127.0.0.1:3100"
  extra_labels {"source":"/data/loki/baimi_sorted.log","tag":"press0505"}
  remove_keys "timestamp,hostname,logtype,source,appname,agent_send_timestamp,tag,duration_parse__debug__"
  <label>
    hostname hostname
    logtype logtype
    appname appname
  </label>
  drop_single_key true
  flush_interval 30s
  flush_at_shutdown true
  buffer_chunk_limit 1m
</match>
```

然后通过:3100/metrics查看存储情况如下：

> loki_distributor_bytes_received_total{tenant="fake"} 2.202853536e+09
> loki_distributor_ingester_appends_total{ingester="127.0.0.1:9095"} 3512
> loki_distributor_lines_received_total{tenant="fake"} 7.078124e+06
> loki_ingester_chunk_stored_bytes_total{tenant="fake"} 5.64079188e+08
> loki_ingester_chunk_compression_ratio_sum 3348.330060841523
> loki_ingester_chunk_compression_ratio_count 848

对比一下，2.2G日志，最后存下来是560MB，占比是25.33%。基本上约等于直接gzip了。

然后通过:3100/loki/api/v1/query_range做查询测试：

* 查{appname:baimi}，因为appname是label，非常快就返回日志了，time结果是0.217秒。
* 查{appname:baimi} |= "101.16.208.94"，因为后面的是要从logline里去grep，所以哪怕最终就命中一条，time结果也是28.479秒。而且立刻开始第二次重复查询，依然花28.715秒，没用上什么cache。
* 查count_over_time(({appname="baimi"} |= "101.16.208.94")[5m])，做timeline计算和直接查询的速度是一样的，time结果是27.892秒。
* 查count_over_time({appname="baimi"}[5m])，等到60秒直接退出无响应了。搜了一下github，说把store配置从v9改成v11可以解决，但是实际试过发现没用。目前暂不清楚loki到底如何解决大数据量的统计问题。

loki目前能做的统计，除了count_over_time是针对日志的，其他的max/min/avg/count/sum这些，都是针对label或者说count_over_time的二次结果。可以说比较有限。

另外，在github上，有很多人在讨论给loki添加索引，或者给loki的label添加高基数支持的事情。有一个百度的PR，就是添加高基数label的：<https://github.com/grafana/loki/issues/1282> 下面已经有loki作者在回复讨论了。

总的来说，loki是一个实现非常简洁，针对场景非常简单的云原生日志方案——你就是按k8s label找日志文件然后自己一行一行看原文就行。

## logscape

再回过头来看fluidity项目的实现。和loki相比，fluidity也有自己的特色。

第一：fluidity在search之外，有一个特殊的dataflow处理，用来更好的处理在微服务场景下越来越多的跟踪链日志。dataflow model如下：

* correlation-Id
* stage: which stage of the flow is it at (i.e. credit or debit)
* node: what is executing it - library, host, node, resource etc
* timestamp: when
* branch-source: correlation-Id
* branch-dest correlation-id

然后，根据corr-id来分桶整合日志，并单独存放span级别的数据到独立文件。然后再自动以天为单位聚合相关统计结果，比如timeline啊、p99啊等，同样也是独立文件存放数据。这样，对dataflow场景的指标报表，就比较快了。

第二：fluidity保持了logscape的特色("奇葩")语法设计，它目前的expression是这样的：

> [bucket | host | tags] | filename | lineMatcher-IncludeFilter | fieldExtractor | analytic | timeControl | groupby

其中，第一段的bucket、host、tags是直接可以映射在S3目录的，fieldExtractor是可以做kv、json和grok解析的，analytic是可以做histo、count、dc等运算的，groupby是做分组统计的。和loki类似的，fluidity目前的groupby也只支持bucket、host、tags这些，不能对extract出来的字段使用。

为了更高效的查看timeline，毕竟这是日志查询最基础的统计需求，fluidity对普通日志也采用了分开存储xxx.events和xxx.histo_10m的方式——真心觉得这个值得loki参考。

下面是一个实际的查询示例：

> tags.equals(cc)|*|WorkflowRunner|field.getJsonPair(corr)|analytic.countEach()|time.series()|*

个人感觉，还不如logscape时代的语法呢……和loki借鉴自promql的语法来说，真的是天壤之别！
