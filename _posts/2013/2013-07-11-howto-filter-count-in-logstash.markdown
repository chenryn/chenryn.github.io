---
layout: post
title: 【Logstash 系列】根据事件统计值报警
category: logstash
tags:
  - ruby
---

之前已经用很多博文说过了 logstash 如何配合 elasticsearch 以及 kibana 来做日子分析和实时搜索。其实 logstash 上百个插件还有很多其他的玩法，绝不是局限在日志搜索统计方面的。今天就展示另一个做法。根据日志中的异常值出现频率报警。

在 logstash 的官网上，针对这个问题采用的办法是讲异常值计数 output 到 `statsd` 中，然后可以用通过观测 `graphite` 图形变化来判断异常。(或者配合 nagios 的 `check_graphite` 插件？) 官网说明见：<http://logstash.net/docs/1.1.13/tutorials/metrics-from-logs>

如果不想一直盯着页面看的话，可以利用另外几个插件来实现类似的做法，比如我要监控访问日志，如果其中 504 状态码<del>每分钟</del>超过 100 次，就报警出来。logstash 配置如下：

**2014 年 08 月 20 日注：上面说法有误，`rate_1m` 的含义是：最近 1 分钟内的每秒速率！**

{% highlight ruby %}
    input {
        stdin {
            type => "apache"
        }
    }
    filter {
        grok {
            pattern => "\[%{HTTPDATE:ts}\] %{NUMBER:status} %{IPORHOST:remotehost} %{URIHOST} %{WORD} %{URIPATHPARAM:url} HTTP/%{NUMBER} %{URIHOST:oh} %{NUMBER:responsetime:float} %{NUMBER:upstreamtime:float} (?:%{NUMBER:bytes:float}|-)"
            type => "apache"
        }
        metrics {
            type => "apache"
            meter => "error.%{status}"
            add_tag => "metric"
            ignore_older_than => 10
        }
        ruby {
            tags => "metric"
#            code => "event.cancel if event['@fields']['error.504.rate_1m'] < 100"
#           2014/08/20: 每秒速率，所以要乘以60s。另，新版本没有了@fields，都存在顶级field里。
            code => "event.cancel if event['error.504.rate_1m']*60 < 100"
        }
    }
    output {
        exec {
            tags => "metric"
            command => "sendsms.pl -m '%{error\.504\.rate_1m}'"
        }
    }
{% endhighlight %}

其中关键在两个 filter。 metrics 插件可以每5秒(前天刚更新了源码，这个值可以自己指定了)更新一次统计值，支持 `meter` 和 `timer` 两种，`timer` 除了 `count` 和 `rate_1|5|15m` 外，还可以统计 `min|max|stddev|mean` 和 `p1|5|10|90|95|99` 等详细数据。

ruby 插件则是直接 `eval` 写在 `code` 配置里的代码。

需要注意的是： `output` 里使用的时候，需要用 `\` 转义 `.`。否则配置解析后会认为变量不存在。这是目前官网文档上写的有问题的地方。我已經跟作者提过，或许过些天会修改。

值得一提的是：metrics 插件的输出是一个全新的 event，而不会去改变原先 grok 生成的 event。
