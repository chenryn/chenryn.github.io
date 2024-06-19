---
layout: post
theme:
  name: twitter
title: 一个有趣的安全分析场景DSL设计
category:  产品设计
---

[NEC美国实验室](https://www.nec-labs.com/publications/)是智能运维领域我长期在关注的一个组织。日志异常检测方面的LogMine和LogLens都出自该实验室。

今天又去看了一下，发现他们最近连着出了好几篇有关安全日志分析的论文，仔细一瞧，还真是有趣，记录下来，给大家分享一下。<https://arxiv.org/pdf/1806.02290.pdf>

论文中选定了APT攻击的三种常见场景，采集auditd和ETW日志，规划好数据模型，按照实体分组和时序分区的原则存入PostgreSQL，并设计了一个专门用于进行这种分析的DSL（攻击调查查询语言，AIQL），以及针对该模型和查询语言特定的存储和执行引擎。执行过程示意如下：

![](https://pic2.zhimg.com/v2-c959c6267cc5a9f4036f3bce97e735d9_r.jpg)

## 场景示例

![](https://pic4.zhimg.com/v2-6f18c10f50e9a11bc0c40b9213ae209f_r.jpg)

比如上面第1个场景，最后的AIQL查询语句如下：

![](https://pic2.zhimg.com/v2-e52a957c5b54cd14b9c8085a268cb1b9_r.jpg)

我们可以看到，这里面有着和普通SQL、SPL、CQL都完全不同的关键字：proc、start、read、write、before、after。（论文中有整个语法树，关键字不止这些）

这前4个，是典型的实体/关系模型，我们通常用图数据库的语法来描述：

```
MATCH evt4 = (p4:Proc{name:"sbblv.exe"})-[conn:CONNECT]->(i1:IP)
WHERE i1.dstip =~ /*.129/
RETURN evt4
```

而后2个，是典型的事件序列，我们通常用复杂事件处理的模式来描述：

```
every-distinct(evt4.name)
  evt1:StartEvent
  -> evt2:WriteFileEvent
  -> evt3:ReadFileEvent(name==evt4.procname)
  -> evt4:ConnEvent
```

但要把二者合二为一，还真是不怎么见过。

论文中除了对比测试不同实现下的分析耗时性能以外，还额外对比了一下不同实现下的查询语句的复杂度，见下表：

![](https://pic2.zhimg.com/v2-0e57fab1422c2a5b6e236338fcf9faa1_r.jpg)

不过，上面说不怎么见过，不代表真的没有。其实还真有一家公司有，这就是SIEM魔力象限里位居中流的LogPoint公司：<https://www.logpoint.com/en/>。

LogPoint公司的SPL是同时兼容普通的搜索统计和流式事件处理的。按照上面的例子，auditbeat日志用LogPoint的SPL语法写，大概会是这样(只看过文档没试用过)：

```
[tag=audit event.action=write_file process.name="sbblv.exe"] as evt3
followed by
[tag=audit event.action=network_flow destination=/*.129/] as evt4
on evt3.process.name = evt4.process.name
| table evt4.process.name, evt4.destination, evt3.file.path
```

看起来好像也不是多很多字？——那是因为auditbeat已经是一个event输出一条日志了，如果是采集的原始auditd日志，一个event有三四条分开的日志记录。那么还要用having same event.id within 5 seconds来先做一次合并。一下子就膨胀很多了~~

总之，能够针对场景实现自定义的DSL语法，真的是很舒服和省力的做法。

