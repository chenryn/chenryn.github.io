---
layout: post
theme:
  name: twitter
title: ChatGPT初尝试(二)：扮演 SPL 专家
category: LLM
tags:
  - ChatGPT
---

第一次尝试，我们让 ChatGPT 扮演 SPL 服务器，让初学者练习 SPL 语句写法。接下来我们进阶思考，把角色扮演翻转过来，让 ChatGPT 扮演一下 SPL 专家，替不想学 SPL 语法的甲方爸爸自动写 SPL 语句，如何？

熟悉 AI 动态的人肯定觉得这个需求很眼熟。对，这就是 text to SQL 问题，或者说 english to SQL 问题的”日志分析版“。

事实上，一年前，splunk 公司曾经在 NVIDIA 技术大会上，做过一个分享：<https://www.splunk.com/en_us/blog/it/training-a-copilot-for-splunk-spl-and-increasing-model-throughput-by-5x-with-nvidia-morpheus.html>

在前 ChatGPT 时代，splunk 选用了比 GPT2 还小的 T5 开源模型，从自己官网文档、社区论坛里精心挑选了 1707 条用例，又请公司 SPL 专家同事手动把 text to SQL问题的数据集转换为 SPL 语句，最后算是整合出来 8000 条干净的训练数据集。但是最终测试结果，完全转换成功的，只有 20%；放宽到 top 10能对就算成功，也只有 28%。可以说，几乎证明了此路不通。

现在，让我们试试看，ChatGPT 能不能成功，有没有进步吧。

## 背景知识问答

谨慎起见，我先问了问 ChatGPT 背景知识，确认尝试可行。背景知识包括：

1. SPL、kusto 是什么？
    * Do you know SPL?
    * Do you know kusto?
2. 二者的区别是什么？
    * so what's the difference between SPL and KQL?
    * is there some syntax function being the same? ——别在意我英文语法对错，反正 ChatGPT 懂了。
3. 二者和 SQL 的区别和转换？
    * can we translate some simple SQL into KQL?
    * can we translate some simple SQL into SPL?
问题比较多，这里就不一一贴截图了。毕竟前面几个问题很简单。

总体来说，Splunk 作为一个已经十多年的老公司，感觉有些老资料是没被 ChatGPT 爬到的：splunk 在09 年上市之前，科普 SPL 时明确说过自己设计思路来源是 SQL，而且也给了 SQL to SPL 的示例。但 ChatGPT 强调说：kusto 是新产品，借鉴了 SQL。也只有 SQL to KQL 的结果才正确。

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_1.png)

相反，哪怕我几次反馈，ChatGPT 给的 SQL to SPL 结果依然不行：

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_2.png)

感觉任务可能要失败啊！不过本着”来都来了“的心态，还是让这个面试没通过的 ChatGPT 继续表演下去吧。

## NL2SPL任务

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_3.png)

看起来像那么回事。不过index 这块似乎没太懂，直接用 yotta 做关键字过滤了。

接下来，出大招。我们直接从 splunk 去年的分享里列出的最好和最差结果的 5 条示例，把 description 部分一模一样的输入到 ChatGPT 提问框里，看看 ChatGPT 的结果，和一年前 T5 的结果如何。这块就不截图了，直接做成对比：

* description(A):	search for the terms error, fail failure, failed, or severe in the events that also mention buttercupgames
    * target:	`buttercupgames (error OR fail* OR severe)`
    * T5:	`index=_internal fail* not [search index=_internal error,fail* error`
    * ChatGPT:	`search (error OR fail OR failure OR failed OR severe) AND buttercupgames`

* description(B):	search the sourcetype field for any values that begin with access_, status 200, and action "purchase". use the chart command to count the number of purchases.the search specifies the purchases made for each product by using categoryId.The difference is that the count of purchases is now an argument of the sparkline() function.
    * target:	`sourcetype=access_* status=200 action=purchase | chart sparkline(count) AS "Purchases Trend" count AS Total BY categoryId | rename categoryId AS Category`
    * T5:	`index=access_* status=200 action=purchase | chart count(price)`
    * ChatGPT:	`search sourcetype="access_*" status=200 action="purchase" | chart count(action) by categoryId | eval purchases=sparkline(count)`

* description(C):	search the sourcetype field for any values that begin with access_, get events with status 200, and action "purchase". then compute the most common categoryId values.
    * target:	`sourcetype=access_* status=200 action=purchase | top categoryId`
    * T5:	`sourcetype=access_* status=200 actionpurchase | top categoryId`
    * ChatGPT:	`search sourcetype="access_*" status=200 action="purchase" | top categoryId`

* description(D):	search the sourcetype field for any values that begin with access_, get events with status 200, and action "purchase". then compute the one most common clientip.
    * target:	`sourcetype=access_* status=200 action=purchase | top limit=1 clientip`
    * T5:	`sourcetype=access_* status=200 actionpurchase | top clientip`
    * ChatGPT:	`search sourcetype="access_*" status=200 action="purchase" | top 1 clientip`

* description(E):	search the sourcetype field for any values that begin with access_, the get price as "Price" by productName, then rename productName column as "Product Name"
    * target:	`sourcetype=access_* | stats values(price) AS Price BY productName | rename productName AS "Product Name"`
    * T5:	`sourcetype=access_. | stats values(price) as price by productName |`
    * ChatGPT:	`search sourcetype="access_*" | eval Price=price | stats values(Price) by productName | rename productName as "Product Name"`

可以说，ChatGPT的结果，真的是”完完全全碾压了“一年前T5的结果：

* 除了场景 B 以外，另外 4 个场景的输出都可以正确运行。
* 场景 B 从语义上也是成立的，只是Splunk实际实现不是这样而已(logscape的语法就是有独立 sparkline 指令)。

## 反馈调整

不过我们肉眼还是可以看到，最后场景 E，ChatGPT 的输出有点过于死板，完全按语序生成，让我们试试看反馈他调整：

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_4.png)

yes！调校没问题，现在给的就是我们手写出来的语句了。

不过心里还是有点小问题，他能记得住这个变化么，让我们再试试换个数据，相同场景再问一次：

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_5.png)

真的记住了。这次没有按原始语句生成那个冗余的 eval！

信心大增啊。最后试试怎么调校一下场景 B 的 sparkline 函数吧：

> No, the sparkline should compute inside the groupby chart command

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_6.png)

不行，ChatGPT 只把 eval 语法换成 chart，再改：

> No, I mean you can do the functions in the same `chart` command

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_7.png)

还是不行，并不知道这个 count 跟前面的 count() 是输入输出关系，看来真的是要明确说出来怎么写：

> you can use `count` nested in `sparkline` functions in `chart` command.

![](/images/uploads/2023-01-31-try-chatgpt-2-nl-to-spl_image_8.png)

成功。

总结一下本次尝试：ChatGPT 当个 SPL 专家是不行了，当个SPL 同桌，教学相长，还是不错的~
