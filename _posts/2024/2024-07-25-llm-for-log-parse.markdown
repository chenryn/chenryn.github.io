---
layout: post
theme:
  name: twitter
title: 大模型时代的日志解析算法总结
category: LLM
tags:
  - AIOps
---

## 上一代 AIOps 的问题

关注 AIOps 日志算法的读者朋友们可能都知道，在日志解析方面，香港中文大学开源的 Drain 在几年前基本已经一统江湖。就连 elasticsearch 的 categorize_text aggregation 实现也使用了 Drain 算法。

但实践上，日志解析问题并没有真正得到解决。原因很简单：行业内通常使用的 loghub 评测基准数据，实际上对每种类型只标注了 2000 条日志。远远不能覆盖实际情况。香港中文大学自己也花大成本，把 80GB 原始日志全部标准一遍，重新发布了 loghub-2.0，如下图所示，基本上日志模板的数量都变多了好几倍。

![](/images/uploads/2024-07-25-image_1.webp)

## 大模型带来的曙光

ChatGPT 发布以后，大家隐隐感觉看到了新的曙光，大模型对通用语义的理解能较好地覆盖到未知的日志模板。很快有 LogPPT、DivLog 等研究出来，证明大模型确实可以有效提升日志解析算法的准确度。

但 ChatGPT 等大模型天生有吞吐量极低的缺陷，不可能直接运用于实践中 TB 乃至 PB 级的海量日志处理。

## 大模型和传统算法相结合

在初期的兴奋劲过去以后，大家纷纷转向了大模型和传统算法相结合的落地道路。这里给大家摘录目前我看到的五篇论文。

### LILAC: Log Parsing using LLMs with Adaptive Parsing Cache

这篇来自香港中文大学的论文，也是 LLM 和 AIOps 传统算法相结合的开篇之作，后来者都是以 Drain 和 LILAC 作为对比基准。

![](/images/uploads/2024-07-25-image_2.webp)

大致的流程，就是从标注数据里抽取 20% 的示例构建模板树，然后日志解析时先尝试匹配先有模板，不能命中的新日志，通过 kNN 算法获取若干相似示例，一起加入提交给 LLM 的 prompt 中，获取新模板并更新模板树。

通过这个 cache，LILAC 可以大大减少解析耗时。但 LILAC 依然无法落地实践，因为他要求预构建这个 cache，甚至比例高达 20%，**没办法从零冷启动**。实际项目中我们不可能一开始就有日志模板标注。

### ECLIPSE: Semantic Entropy-LCS for Cross-Lingual Industrial Log Parsing

这篇来自北航的论文，除了 loghub-2 以外，还爬取了主流开源软件的logger 代码进行分析：

![](/images/uploads/2024-07-25-image_3.webp)

并提供了一个匿名实际环境的模板数量：

![](/images/uploads/2024-07-25-image_4.webp)

从这几个表里我们可以看到，logger 代码的模板其实远超过算法聚类出来的模板数。AI 一般还是会过度收敛。

具体的方案如图：

![](/images/uploads/2024-07-25-image_5.webp)

简单解释，就是：

1. 做完基础的实体占位符(TIME/IP 等)预处理以后，交给大模型来提取这条日志里的核心关键字。大模型会重点关注一些语义上值得注意的词，比如 deny 啊、close 啊这些。这样还能**避免一些 open/close 被过度合并**。
2. 把这些核心关键字，和对应的日志模板，做成词典表，存入 Faiss 向量数据库。因为日志内容很多时候是代码拼出来的词——大家都知道的，驼峰还是下划线都能争很久——对普通的 embedding 模型不友好，论文也没考虑单独训练一个embedding 模型，而是简化一下，直接**提取 punct 标点符号做为向量**。反正同一个模板内的punct 应该比较类似，这个思路在过去 splunk 也好，在 logpunk 论文也好，都验证过了。
3. 新日志来了，也这么处理以后，**在 Faiss 数据库里做 kNN 检索，拿到最接近的几个模板**。然后用 LCS 匹配，来判断是新模板，还是更新老模板。

最后的评测，当日志模板数量超过 300 后，耗时优势就体现出来了。

### AdaParser: Log Parsing with Self-Generated In-Context Learning and Self-Correction

这篇论文来自北大，从架构图可以看到这部分叫 SG-ICL 的，和北航思路类似，并且支持在示例库为空时冷启动（但效果有 20% 的下降）。额外增加的是右侧的 template corrector模块（消融实验说明这个效果比缓存还重要）：

![](/images/uploads/2024-07-25-image_6.webp)

corrector 模块的逻辑分为**模块校正**和**变量校正**两部分，具体思路是：

1. 模板匹配校正（Template Matching Correction）：确保生成的模板能够准确匹配输入的日志消息
    * 将LLM生成的模板转换为正则表达式（例如，将模板中的通配符<*>转换为正则表达式中的.*）。
    * 使用该正则表达式检查是否能够精确匹配原始日志消息。
    * 如果正则表达式与日志消息不匹配，说明存在“Plausible Template”错误，即模板看起来合理但实际上不准确。
    * 通过设计一个校正提示（prompt），要求LLM重新生成模板以修正错误。
2. 变量抽象校正（Variable Abstracting Correction）：确保日志消息中的重要标记（如异常信息）不会被错误地抽象为变量
    * 检查LLM生成的模板中使用通配符<*>替代的标记。
    * 确定这些标记是否包含或紧跟关键标记（如“Exception”，“failed”，“interrupted”等），这些关键标记对于工程师理解系统状态至关重要。
    * 如果发现关键信息被错误地抽象为变量，存在“Broad Template”错误，即模板过于宽泛，丢失了重要信息。
    * 使用校正提示指导LLM不要将这些关键信息视为变量，而是应作为常量保留在模板中。

![](/images/uploads/2024-07-25-image_7.webp)

最终在 loghub-2.0的评分效果也很好。

![](/images/uploads/2024-07-25-image_8.webp)

然后替换不同的基座大模型对比，结果其实比较打脸，后面 4 个模型，在 base 情况下，都比 GPT3.5 落后不少。加上adaparser，在 0% 启动的情况下，才算是追上 GPT3.5 的 base 情况。

* 其中 claude3-sonnet 算是超过 base，接近 GPT3.5 下的 adaparser，确实潜力最大。
* 而 **qwen1.5 在 adaparser 加持下，依然比不上 base 的 GPT3.5**——也就是说在日志方面，国产大模型 deepseek 比 qwen 更好？

![](/images/uploads/2024-07-25-image_9.webp)

最后就是执行耗时，比 LILAC 也有提升，已经非常逼近传统的 Drain 算法了。

### ULog: Unsupervised Log Parsing with Large Language Models through Log Contrastive Units

这篇论文同样出自香港中文大学。和 LILAC 相比，ULog 主要解决冷启动和耗时问题——不过解决思路是并行化处理。如下图所示：ULog 设计了一套 LCU 双层分桶。第一层直接**按日志长度快速切分（假定相同模式的日志，长度应该差不多）**，第二层才是分词聚类。这样，第一层分桶后，就可以并行处理。

![](/images/uploads/2024-07-25-image_10.webp)

然后在第二层分桶聚类后，对每个聚类采样 3 条日志，作为这个 LCU 的样例。**采样同时考虑模板的通用性和变量的特殊性**。然后把样例日志和一些注意事项、变量说明，一起作为 prompt提交给大模型。

最后的耗时评测结果。不并行的话，效果很一般，但并行以后，很接近 Drain。甚至我们可以看到也略微领先上面那篇 AdaParser：

![](/images/uploads/2024-07-25-image_11.webp)

### LogBatcher: Stronger, Cheaper and Demonstration-Free Log Parsing with LLMs

最后一篇，来自 AIOps 领域不太常见的重庆大学。代码公开在：https://anonymous.4open.science/r/LogBatcher/README.md，也是不太常见的地方。

从论文设计中来说，作者应该也是对 AIOps 不太熟悉，其日志聚类过程就使用了标准的 TF-IDF 和 DBSCAN 算法实现。在缓存管理部分，大致流程：

1. 存储解析模板：已解析的日志模板存储在缓存中。每个缓存条目通常包含三个值：
    * 新生成的日志模板。
    * 可以匹配该模板的参考日志。
    * **匹配频率，即该模板已经匹配了多少日志**。
2. 匹配过程：当新的日志数据到来时，LogBatcher会首先检查这些日志是否可以使用缓存中的模板进行匹配。这通过以下步骤完成：
    * 使用正则表达式将日志模板中的占位符（例如“<\*>”）替换为通用匹配符号（例如“(.?)”），以便可以精确检查日志和模板是否匹配。
    * 利用参考日志来验证其长度是否与目标日志一致，从而提高缓存匹配的准确性。
3. 动态排序：为了提高缓存的效率，LogBatcher还会动态地对缓存中的模板进行排序，使得频繁出现的模板可以首先被检查。
4. 处理不匹配的日志：如果日志与缓存中的模板不匹配，这些日志将被发送至LLMs进行解析。LogBatcher 会积攒一批新日志后，再**通过Determinantal Point Process算法来尽量保证采样日志的多样性**。
5. 更新缓存：每当LLMs解析出一个新的日志模板时，这个模板就会被加入到缓存中，同时记录参考日志和匹配频率，以便未来使用。

论文的效果评估标准也和其他论文不完全一致，这里就不贴了。但是有个比较有趣的数据，作者评估了自己方法的 token 消耗量，对比 LILAC 大大减少：

![](/images/uploads/2024-07-25-image_12.webp)

此外，还更换了基座模型对比，发现 codellama-7B 可能比 llama3-70B 还好一些：

![](/images/uploads/2024-07-25-image_13.webp)

## 总结

看完 5 篇论文，其他大家总体思路是比较类似的：

1. 通过日志模板的 cache 来减少对 LLM 的调用
2. 模板 cache 的内容可以利用传统的 AIOps 算法来构建
3. 同一个模板的日志样例，采样时要同时考虑通用性和变量特殊性
4. 大模型除了RAG方法来实现基于样例的新模板生成，还可以实现基于关键语义的模板校正

相信在 GPU 资源充裕的情况下，新一代日志模板解析算法，应该也会很快普及了。

