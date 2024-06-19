---
layout: post
theme:
  name: twitter
title: 日志分析的模式发现功能实现(3)-其他厂商
category: logstash
tags:
  - elasticsearch
  - oracle
  - vmware
---

[《山寨一个 Splunk 的事件模式功能》](/2016/2016-07-18-event-pattern/) 和 [《日志分析的模式发现功能实现(2)-sumologic》](/2017/2017-11-09-event-pattern-sumologic/) 前两篇，已经分别讲过了商业产品老大splunk、开源项目老大ELK、云服务老大sumologic分别的实现做法。除了他们以外，还有一些其他实现，这次一并讲完。

## prelert

prelert是一个老牌公司了，原先是基于splunk平台做异常检测产品（卖点是比splunk的rare、predict、anomalies指令更好），去年被ES收购。到目前为止prelert和ES x-pack的整合工作其实都没有完全结束。所以讲它功能，还是直接看原先的老文档更清晰。

老版的prelert思路和sumologic非常非常像。

先通过prelertcategorize指令做日志分类（也就是sumo家的logreduce指令）：

![](https://pic2.zhimg.com/v2-e225042a85b5d531333a974d668d1d61_r.jpg)

这个地方注意到，prelert既没有提取keyword，也没有汇聚signature，而是列出同一个模式下的4条样例日志给用户自己看。这个做法可以说比较保守。

此外，多出来两列，sparkline和sourcetype：

* sparkline这个想法还是不错的。我们可以**直接看到单个模式在一段时间内的事件数走势。对于偶然出现或者暴增暴跌的情况，可以一眼看出来**。
* sourcetype这个就有趣了，这意味着，**做聚类时，首先是基于一个sourcetype做了分桶的。这样可以减少一些计算量**，比较同一个sourcetype内的数据应该相似度比较大，而不同sourcetype相互之间相似度应该较小——但是这有一个前提，sourcetype是按照比较合适的规则进行了设计——这对于完善的商业产品可能问题不大，对于互联网公司内部业务运维来说，就不那么容易了。

其次，对具体某一类日志，可以保存成eventtype（注意到截图里生成的过滤语句，有一个len(_raw)<=129，这块跟splunk计算_punct字段有类似，splunk计算_punct时就也规定了只算前128个字符）：

![](https://pic2.zhimg.com/v2-023bd866dfb6d6b6a2d87b3713f0d655_r.jpg)

最后，也可以通过prelertautodetect指令做异常检测。这时候可以直接对总趋势做，也可以选择基于普通字段做groupby，也可以选择基于前面生成的prelertcategory做。为了区分异常检测的纵向时间维度和横向密度维度，可以用by和over两个从句来分别制定。效果如下：

![](https://pic3.zhimg.com/80/v2-32a22c2fc9bdace6b60a3d97e7a95242_720w.webp)

不过perlert被elastic.co收购以后，以上模式发现功能，只保留了异常检测的部分。我们只能在异常详情的列表里，隐约看到category examples还是那熟悉的4行日志样例了：

![](https://pic1.zhimg.com/v2-01d26a3b0a833e384158712e1858d4f4_r.jpg)

## oracle

oracle公有云上，提供了日志分析产品，叫OMC LogAnalytics。也提供了诸如SPL、模式发现等著名的日志分析功能。其模式发现(cluster指令)界面如下：

![](https://pic2.zhimg.com/v2-5655b8e12c3459a8df64d4c33ad310c5_r.jpg)

一本正经的把clusterID也列出来，真是淳朴啊~其余列，和prelert类似，也是保证了一个聚类肯定在同一个logsource内部做的，也带了一个trend图。

不过模式样例，即没有keyword也没有signature，还不提供多条……

## vmware

vmware的日志产品，叫vRealize Log Insight。特点是对vmware自家产品的日志解析分析的很好（废话）……

其中提供了一个叫做log grouping的功能：

![](https://pic3.zhimg.com/v2-36710bcbff828dbe48ec3d731ee20c0a_r.jpg)

可以看到，这个界面更偏向splunk而非sumologic风格。

该功能会查找日志模式，然后把signature部分，高亮显示。但是区别是：并不用`***`来取代signature，而是留着样例日志里的原文高亮。

vmware这里发现的模式，可以用来后续过滤，也就是截图中的events like this功能。
