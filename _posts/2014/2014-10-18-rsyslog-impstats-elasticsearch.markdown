---
layout: post
theme:
  name: twitter
title: Rsyslog 性能数据 impstats 直接写入 Elasticsearch
date: 2014-10-18 21:48:00
category: logstash
tags:
  - rsyslog
  - elasticsearch
---

Rsyslog 的性能数据，可以通过自带的 impstats 插件输出。但是在用的比较复杂的场景下，每次输出都会有好几十个 action 的各种状态，肉眼观察变得比较困难，这时候，我们可以直接输出给 Elasticsearch ，然后利用 Kibana 做快速搜索和分析。

Rsyslog 官方提供了直接输出给 Elasticsearch 的插件：`omelasticsearch`。配置如下：

    module(load="omelasticsearch")
    module(load="impstats" interval="120" severity="6" log.syslog="on" format="json" resetCounters="on")
    template(name="logstash-index" type="list") {
        constant(value="logstash-rsyslog-")
        property(name="timereported" dateFormat="rfc3339" position.from="1" position.to="4")
        constant(value=".")
        property(name="timereported" dateFormat="rfc3339" position.from="6" position.to="7")
        constant(value=".")
        property(name="timereported" dateFormat="rfc3339" position.from="9" position.to="10")
    }
    template(name="plain-syslog" type="list") {
        constant(value="{")
        constant(value="\"@timestamp\":\"") property(name="timereported" dateFormat="rfc3339")
        constant(value="\",\"host\":\"")    property(name="hostname")
        constant(value="\",")   property(name="msg" position.from="2")
    }
    if ( $syslogfacility-text == 'syslog' ) then {
        action( type="omelasticsearch"
                template="plain-syslog"
                server="10.13.57.35"
                searchIndex="logstash-index"
                searchType="impstats"
                bulkmode="on"
                dynSearchIndex="on"
        )
        stop
    }

这里用到一个小窍门。impstats 只是 message 部分内容是 JSON 格式，那么如果合在总的内容里，可能就得跟老版的 logstash 事件格式一样，专门放在 `@fields:` 里面去了。但是，利用 `position.from` 参数，把 message 部分的开头 `{` 给删掉，就把整个内容都提升到顶层了，变成了新版 logstash 的事件格式了！

Rsyslog 的 template 语法多变，实现这个同样的目的，在 `mmjsonparse` 或者 `mmnormalize` 的配合下，就可以有不同写法：

* Rsyslog 官方的 `$!all-json` 玩法 [Parsing JSON (CEE) Logs and Sending them to Elasticsearch](http://www.rsyslog.com/json-elasticsearch/)
* Rackspace 官博的 `subtree` 玩法 [rsyslog & ElasticSearch](https://developer.rackspace.com/blog/rsyslog-and-elasticsearch/)

normalize 是 rsyslog 作者自己写的一个日志格式分析工具，搞怪的是它的文本格式示例文件后缀名叫 `.rb`，不是 Ruby，而是 RuleBase……

RuleBase 支持的[语法](http://www.liblognorm.com/files/manual/index.html)不多：

* date-rfc3164: date as specified in rfc3164 (example: %date:date-rfc3164%)
* date-rfc5424: date as specified in rfc5424 (example: %date:date-rfc5424%)
* ipv4: IP adress (example: %ip:ipv4%)
* number: sequence of numbers (example: %port:number%)
* word: everything until the next blank (example: %host:word%)
* char-to: the field will be defined by the sign in the additional information (example: %tag:char-to:\x3a%: (x3a means ":" in the additional information))
* quoted-string: If a quoted string is present, a property can be filled with the whole string (example: %quote:quoted-string%)
* date-iso: date in ISO format (example: %date:date-iso%)
* time-24hr: detects time in 24hr format (example: %time:time-24hr%)
* time-12hr: detects time in 12hr format (example: %time:time-12hr%)
* iptables: parses IP tables messages and fills properties accordingly(example: %tables:iptables%)

从这个格式设计也可以看出，主要还是用来分析系统日志比较多。

目前来看，使用 Rsyslog 做整套日志处理系统的话，在数据结构化这步，还是用 [mmexternal](http://www.rsyslog.com/doc/v8-stable/configuration/modules/mmexternal.html) 插件来完成比较合适。

mmexternal 模块类似 squid 的 `url_rewrite_program` ，都是支持用任意语言写的脚本，死循环接收 STDIN(可以配置传输 line 还是 json 格式)，处理完成后(JSON 格式)输出给 STDOUT 即可。官方示例见：<https://github.com/rsyslog/rsyslog/blob/master/plugins/external/messagemod/anon_cc_nbrs/anon_cc_nbrs.py>。性能如何，有待测试了。
