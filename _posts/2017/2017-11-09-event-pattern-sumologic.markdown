---
layout: post
title: 日志分析的模式发现功能实现(2)-sumologic
category: logstash
tags:
  - sumologic
---

[《山寨一个 Splunk 的事件模式功能》](/2016/2016-07-18-event-pattern/)里我们曾经介绍了splunk里的模式功能，以及如何使用ELK做一个简单的模拟。

在日志分析这个领域，除了splunk和ELK，还有很多其他的玩家。那么后续也要说说其他玩家在这方面的处理。

sumologic是美国最大的日志分析云服务商。模式发现(sumo语境中叫logreduce)及其后续扩展(sumo语境中叫anomalies)功能，也是sumologic最大的亮点。下图是其模式发现功能的截图：

![](https://pic3.zhimg.com/v2-4328cb30a033b0ad5f80b302f52f1bde_r.jpg)

可以发现这个界面上的信息和操作，和splunk差别是很大的：

1. 高亮标识的，不是单个keyword，而是诸如`****`，`$DATE`，`$URL` 一类的signature。
2. 有明确的Score，据称用的是KL散度。
3. 提供了对单个模式进行晋级或降级的标记。
4. 还提供了对单个模式进行细分，或者对多个模式进行归并的操作。

这个归并的操作，非常的灵活，用户可以自己鼠标划选，指定应该把哪些内容归并成signature：

![](https://pic1.zhimg.com/v2-e354c711eea9a99839cee6710f88c0ec_r.jpg)

*注：除了功能上的区别，还有一个技术上的区别，sumologic支持对所有搜索结果进行logreduce，而splunk会对过多的搜索结果进行截断，只返回有限数据的pattern。*

这些不同中，**我最赞赏的是signature设计对比keyword的优势！**

我们都知道，日志其实是由程序代码中的各种logger打印出来的。比如这段：

```java
  public void setTemperature(Integer temperature) {
     oldT = t;
     t = temperature;
     logger.debug("Temperature set to {}. Old temperature was {}.", t, oldT);
     if(temperature.intValue() > 50) {
       logger.info("Temperature has risen above 50 degrees.");
     }
   }
```

这段程序执行几亿遍，日志的实际含义也就是这么两条代码。那么我们追本溯源，希望看到的日志模式，应该也就是这么两行文本。以signature的设计思路，我们看到的日志模式会是这样：

> $DATE DEBUG Temperature set to \*. Old temperature was \*.
> $DATE INFO Temperature has risen above 50 degrees.

多么的一目了然和漂亮！

当然，从更高层级来说，这两行代码，都是同一个方法里的，那么和其他方法、其他类的日志相比，它两又可以归并成更高一些的模式：

> $DATE \* Temperature \*\*\*\*\*.

至于默认给用户返回哪种模式，这是另一个问题。

sumologic对这个问题的回答之一，就是用户标记操作。默认的模式评分在0-10之间。而用户如果点过晋级的模式，以后固定就是最高的10分，点过降级的模式，以后固定就是最低的0分。

此外，sumologic还会自动分析被你点过降级的那些日志模式。比如说，如果他们共同含有database单词，那么以后还有database单词的日志，它归属的signature评分自动会被降低。(这里隐藏有一步，它是怎么确定这个database单词的？我猜测可以类比splunk的event pattern功能，其中有一个内部的findkeywords指令。不过splunk找到的keyword只是简单的保存为eventtype，没有sumologic这种label回馈给机器学习算法的过程。)

还有一个细节：晋级和降级是以用户操作为单位的，不同用户登录上来，可能因为自己过去的操作历史看到不同的结果。而细分是以租户整体为单位的，不同用户登陆上来，看到的都会是细分完的。

## And More

sumologic的模式发现功能，和所有其他厂商相比，更进一步的地方是：并没有停步在发现并展示模式。还扩展出来了后续的anomalies一整套逻辑。可以说，sumologic是唯一一家拥有完整回环的文本异常检测的AIOps公司。

![](https://pic2.zhimg.com/v2-94b5531634e3b811a4cf3631fe894175_r.jpg)

整套思路大致如下：

1. 预定义查询范围，在该范围内，对最近6小时的日志进行logreduce；
2. 对比较罕见的signature，会存入一个独立的sumologic_anomaly_events索引中待查，也意味着可以对这个索引做告警；
3. 其中新发现的signature，记录为unlabel_event_xxxx，提供给用户进行模式命名、级别设定，还可以填写处理意见（当然也可以在这里进行晋级降级细分等操作进行反馈）；
4. 对已经label的signature，按照过去设计的级别，做一个同时间轴的泳道图展示，这样可以有一个很醒目的时间相关性的观感；
5. 可以对某一时刻的anomalies整体状态做快照备用。

![](https://pic1.zhimg.com/v2-f9257a13d9afaf7bd409c35c3212e518_r.jpg)

这一套下来，就串联了异常检测、告警、根因分析、事后报告等一大连串智能运维功能。

不过话说回来，为啥听起来这么厉害的功能，却没有其他人跟进，或者说大多数人并不知道呢——因为文本异常毕竟是少见的，指标异常、海量指标异常，才是目前大多数IT团队亟待解决的难题！

可以说：sumologic是做了一把屠龙刀……

