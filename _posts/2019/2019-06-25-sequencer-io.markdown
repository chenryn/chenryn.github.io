---
layout: post
theme:
  name: twitter
title: sequencer.io项目介绍
category: aiops
tags:
  - 日志解析
---

在日志分析领域，如何从非结构化的原始日志文本转换成结构化的字段参数值，一直是非常重要而又麻烦的工作。

我们先回顾一下各种常见的做法：

最传统的办法，自然是写正则表达式。但是正则表达式万一写得不好，性能会很差，于是re2库出来，通过限定一些不常用的功能，来提高通用场景下的效率。

另一类办法，是通过改造日志文本，避免使用正则表达式。常见的两种改造方式，一种是改成kv或json格式，一种是改成固定分隔符方式。

当然，改造本身在很多时候是不可行的。所以大家还是要继续研究如何提高解析本身的效率。于是陆续有一些新的变种出来。

比如logstash先是提出了Grok正则的概念。把一些常见的字段正则定义为grok，解析的时候直接引用grok，可以降低一些普通人写正则的压力。

接着logstash又提出了dissect解析的概念。主要就是利用日志中一些不用提取字段的固定文本，比如空格啊，标点符号啊，作为定位锚点，来做格式解析。比较有特色的是提供了动态kv的支持。比如一段带请求参数的url，可以写成：`http://%{domain}/%{?url}?%{?arg1}=%{&arg1}`

类似的，rsyslog和syslog-ng两个项目，也有自己独特的高性能解析功能。在rsyslog里，叫[mmnormalize模块](https://github.com/rsyslog/liblognorm)，大致长这样：

> rule=:%date:date-rfc3164% %uhost:word% %tag:word% %notused:char-to:x3a%: %msgnumber:char-to:x3a%: access-list inside_access_in permitted %protocol:word% inside/%ipin:ipv4%(portin:number%) -> outside/%ipout:ipv4%(portout:number%) %notused2:char-to:]%]

在syslog-ng里，叫[patterndb模块](https://github.com/balabit/syslog-ng-patterndb)。大致长这样：

> <pattern>lame-servers: info: @ESTRING:dnslame.reason: resolving@ '@ESTRING:dnsqry.query:/@@STRING:dnsqry.type@/@STRING:dnsqry.class@': @IPvANY:dnsqry.client_ip@#@NUMBER:dnsqry.client_port@</pattern>

可以看到，不管是logstash，还是rsyslog，还是syslog-ng，大家的思路都比较一致，利用固定文本和字段参数的位置关系，简化和避免回溯，提高效率。

不过也可以看得出来，每家搞的语法，其实写起来依然还是比较费劲，就像正则表达式写到最后全是\s和\S一样，mmnormalize写到最后估计全是%word%和%char-to%。而且面对复杂的系统、设备日志，依然是需要见一种日志写一条解析规则。三家的思路，都只能说是解决了运行高性能的问题，不能说解决了最终用户高效使用的需求。

前段时间看到另一个开源项目，相比前者又进了一步。今天有空，稍微做点记录，看看大家是否喜欢。项目名字叫：sequence。github地址见：
<https://github.com/zentures/sequence>

这是一个基于最终状态机实现的golang解析器。在scan阶段，高速识别token的类型是时间、ip地址、url地址、JSON和普通字面量。你也可以预定义一些fields，这样识别token的时候可以直接按照预定义来命名字段。

这些看起来和rsyslog们本质上差别也不大。最有特点的部分是：sequence提供了一个单独的analyze方法——**你只需要提供一段日志样本，运行analyze方法，可以自动生成对应的pattern结果**——不再用你自己费尽看日志，做总结，写解析规则了。

按照 <http://sequencer.io/manual/analyzer/> 的说法，从45万行的思科ASA、SSH和sudo混合日志中，自动分析出来了103个模式：

> $ go run sequence.go analyze -i ../../data/asasshsudo.log -o asasshsudo.analyze
> Analyzed 447745 messages, found 103 unique patterns, 103 are new.

analyze方法利用token分词结果来构建树，相同父节点下的自然就是字段参数，可以推导字段类型了。由于作者写这个项目针对的就是系统日志和设备日志，所以他直接按经验总结了几个原则：

* email和hostname地址，会严重影响分词性能，所以应该后检测；
* 第一个token先检查一下属不属于syslog header格式；
* 根据=等号分隔来确定前后的键值，作为对应的字段命名；
* 类似from/to这种字眼很容易出现在ip/port前面，所以可以定义一些prekeys，对这些可以跳2个tokens做键值映射；
* 一些枚举类型的参数，可以预定义好。那么树形成以后，叶子节点数量不大的，可以尝试根据预定义替换成字段参数；
* 按照规律调整一些多次出现的token命名：
    * 第一个timestamp改叫msgtime
    * 第一个url改叫object
    * 第一个ip/mac/host/email改叫srcip/srcmac/srchost/srcemail，第二个ip/mac/host/email改叫dstip/dstmac/dsthost/dstemail
* 最后，如果srcip或者dstip后面跟着:冒号或者/斜线，加上一个数值的，把这个数值改叫srcport或者dstport。

sequence项目的analyze方法，可以说是我见到的最接近日志模式发现而又完全不用任何机器学习算法的实现了。考虑到目前AIOps里，算法效果比较好的部分其实也集中在系统日志设备日志上，甚至可以说，sequence没准比AI不差什么。

遗憾的是，因为作者个人精力问题，项目已经在17年宣告不继续开发了。大家谁有兴趣的，可以联系作者，接起这副重担来~~
