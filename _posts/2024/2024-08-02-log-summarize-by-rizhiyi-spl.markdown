---
layout: post
theme:
  name: twitter
title: 日志易 SPL 实现基于大模型的海量日志总结
category: LLM
tags:
  - 文心一言
  - 通义千问
  - 日志易
  - python
---

前段时间，阿里开源了qwen-agent，可以对长文档进行 RAG 增强的对话问题。但在对话之前，还缺了第一步——人们总是习惯先问一句“总结一下这篇文档说了什么”，然后再根据总结来具体提问。“长文总结”，其实是大模型应用要过的第一关。

在 IT 运维领域，情况也类似。我们有强大的搜索引擎技术，却总要先靠经验猜测几个关键字，就是因为没法预知海量日志说了啥。

日志聚类技术试图解决这个问题，但聚类和模式识别把变量部分抽象成占位符，也丢失了大量信息。怎么把这些变量信息尽可能保留住，成为当前需要克服的主要问题。

## 一、业界的相关尝试

业界已经有一些简单的海量日志总结方案在尝试。这里给大家讲两个。

第一个，微软云 service bus 团队，他们在《Intelligent Solutions for Retroactive Anomaly Detection and Resolution with Log File Systems》论文中采用的方案是：

1. 上传错误日志文件离线处理，预训练了一个异常评分的 bert 小模型；
2. 先根据时间趋势图展示异常评分，帮助用户缩小范围到单个时间段；
3. 对这个时间段的 1000 条日志聚类，对每个聚类采样 10 条日志，调用 LLM 生成标题描述；
4. 最后用户**自己看完每段描述**后提问，后端 RAG 召回产品文档作答。

界面如图：

![](/images/uploads/2024-08-02-image_1.webp)

第二个，阿里云 Flink 团队，他们在《RCAgent: Cloud Root Cause Analysis by Autonomous Agents with Tool-Augmented Large Language Models》论文中，针对 Flink 日志设计了一套非常详尽的总结方案，我个人不是 Flink 专家，无法评判，贴出来供大家参考：

1. 首先对每行日志向量化；
2. 然后滚动处理**每 200 行日志，相互之间一一计算**向量相似度和行数距离，得到权重矩阵；
3. 然后构建图，图上的节点是每行日志，边是日志之间的权重；
4. 然后运用Louvain社区发现算法，进行图聚类和贪婪去重，让每个聚类之间日志无重叠；
5. 然后对每个聚类里的日志，进行 RAG 增强，生成 ICL 提问，要求 LLM 生成解释和证据（RAG 来源是 flink advisor 知识库）；
6. 然后计算 LLM 生成的证据文本，和原始日志文本之间的LEVENSHTEIN距离，再过滤一遍可能的幻觉解释（论文说有些幻觉输出是在解释示例而不是最后的实际问题）；
7. 最后，把每个聚类生成的解释和证据，再给到 LLM 二次总结成最终结果返回。

从二个团队的做法都可以看到，大家仅在出错时，才对错误时段的日志做总结，从"场景"层面缩小日志量、突出核心信息。但方案中如何保留变量信息、甚至扩展更多信息，就各有各的设计，比较依赖人的经验了。

## 二、日志易上的简易实现效果

今天，我参照类似的想法，并从上期介绍的《[大模型时代的日志解析算法总结](/2024/07/25/llm-for-log-parse/)》里，引入 punct 分组和 Determinantal Point Process 算法，即尽量保持信息的多样性，又不过高要求大模型的上下文支持，实现快速高效的海量日志总结。

首先给大家看一眼在日志易仪表盘上的最终效果：

![](/images/uploads/2024-08-02-image_2.webp)

对应的日志易 SPL 语句如下：

```
* | eval msg=raw_message
  | parse field=msg mode=sed "s/(\b)[a-zA-Z0-9]*//g"
  | parse field=msg mode=sed "s/\s+/_/g"
  | stats list(raw_message) as 'raw_message' by msg
  | streamstats count() as cluster
  | fields - msg
  | mvexpand raw_message
  | fit TFIDF analyzer="word" max_features=50 from raw_message
  | dpp k=5
```

这段语句中大部分内容是为了照抄 punct 分组效果，实际上日志易本身自带了一些基础的机器学习能力，所以，我们可以直接在 SPL 中完成聚类、特征值提取，更直接的SPL实现方案：

```
* | eval msg=raw_message
  | fit TFIDF analyzer="word" max_features=50 from raw_message
  | fit DBSCAN eps=0.2 from raw_message_tfidf_*
  | dpp k=5
```

所以，我们只需要额外再实现 DPP 采样和 LLM 调用即可。也就是上面语句中最后一段用到的自定义 SPL 指令：dpp。

## 三、dpp 指令介绍

日志易支持用户自己编写 python 程序，继承日志易特定类和实现方法，然后上传就可以使用。

程序中还可以复用日志易 fit 指令自带的 sklearn 机器学习库，不用操心安装部署问题。

```python
#!python3
import os
import sys
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

executehome = "/opt/rizhiyi/parcels/splserver"
lib_path = os.path.join(executehome, 'bin', 'custom_commands', 'lib')
sys.path.insert(0, lib_path)

from src.cn.yottabyte.process.centralized_handler import CentralizedHandler
from src.cn.yottabyte.process.util import loggers
from src.cn.yottabyte.process.util import data_util
from src.cn.yottabyte.process.table import Table

logger = loggers.get_logger().getChild('DPPHandler')

class DPPHandler(CentralizedHandler):

    def initialize(self, meta):
        # 获取自定义指令运行参数，这里我设计
        # k 来代表每个聚类的采样数量
        # by_field 代表是输出每个聚类总结还是全局总结
        self.by = None
        args_dict, args_list = data_util.get_args_from_meta(meta)
        if args_dict:
            self.k = args_dict.get("k", "3")
            self.by = args_dict.get("by_field")
        return {'type': 'centralized'}
        
    def execute(self, meta, table):
            finished = meta.get("finished", False)
        if finished:
            # 自定义实现部分
            ...
        else:
            table = Table()
            return meta, table

if __name__ == "__main__":
    handler = DPPHandler()
    handler.run()
    handler.close()   
```

接下来，我们直接从 LogBatcher 开源实现中，复制对应的 dpp_sample() 函数。

```python

    def dpp_sample(self, S, k):
        # S: similarity matrix
        # k: number of items to sample
        n = S.shape[0]
        # Initialize empty set Y
        Y = set()
        for _ in range(k):
            best_i = -1
            best_p = -1
            for i in range(n):
                if i not in Y:
                    # Compute determinant of submatrix
                    det_Yi = np.linalg.det(S[np.ix_(list(Y) + [i], list(Y) + [i])])
                    # Compute probability of adding i to Y
                    p_add = det_Yi / (1 + det_Yi)
                    if p_add > best_p:
                        best_p = p_add
                        best_i = i
            # Add best item to Y
            Y.add(best_i)
        return list(Y)
```

注：我个人已经习惯一百行以下的代码让智谱清言实现。然后对比二者时学到一个有趣的知识点，DPP 有连续型和离散型两种不同实现，智谱默认会给数值连续型的采样方法，而 LogBatcher 里是针对文本离散型的。要注意差异。

然后就是 LLM 部分。作为实验，我直接调用公开的免费 API 实现。注意：百度千帆平台上提供的 ernie-speed 是无限制永久免费，而阿里云上提供的 qwen 系列是赠送一定量 token，且有 TPM 限速。

这部分代码就不贴了，百度和阿里官方文档中 HTTP 示例基本可以原样复制使用。如果采用 access_token 方式，建议额外存储一下，不用每次调用都重新获取。

实践发现，ernie-speed-128k 的总结效果确实**烂到爆炸**（复读了一遍 prompt 结尾的内容）！所以，综合考虑了效果与成本控制后，我决定：对每个聚类内的采样日志总结时，采用 ernie-speed，并发调用；而对 ernie-speed 输出的总结结果，再做二次总结时，则单独调用一次 qwen-plus。

```python
    def process_cluster(self, cluster_rows, features):
        # 提取 tfidf 特征值，构建 numpy 数组
        feature_values = np.array([[float(row[feature]) for feature in features] for row in cluster_rows])
        # 使用 sklearn 中的方法构建相似性矩阵
        S = cosine_similarity(feature_values)
        # 应用 DPP 采样
        sampled_indices = self.dpp_sample(S, int(self.k))
        sampled_rows = [cluster_rows[i] for i in sampled_indices]
        # 发送采样日志，由大模型生成摘要
        content_parts = [
            "你是 IT 运维和网络安全专家，请总结下面这段日志内容，输出尽量简短、非结构化、保留关键信息："
        ] + [row['raw_message'] for row in sampled_rows]
        content = "\n".join(content_parts)
        summary = self.llm_summarize(content, 'ernie')
        return summary

    def execute(self, meta, table):
        # 获取SPL输入的数据表中，有哪些 tfidf 特征向量字段
        features = [field for field in table.fields if 'tfidf' in field]
        finished = meta.get("finished", False)
        if finished:
            # 准备输出给SPL后续处理的数据表
            table = Table()
            table.fields = ['cluster', 'summary']
            # cluster分组内数据，并发应用DPP采样、发给LLM总结
            with ThreadPoolExecutor(max_workers=5) as executor:  # 可以调整线程数
                # 构建并发任务
                future_to_cluster = {
                    executor.submit(self.process_cluster, cluster_rows, features): cluster_id
                    for cluster_id, cluster_rows in clusters.items()
                }
                # 收集结果，追加到准备好的SPL数据表里
                for future in concurrent.futures.as_completed(future_to_cluster):
                    cluster_id = future_to_cluster[future]
                    try:
                        summary = future.result()
                        table.add_row({'cluster': cluster_id, 'summary': summary})
                    except Exception as exc:
                        logger.error(f'Cluster {cluster_id} generated an exception: {exc}')

            # 不要求分组输出，二次总结
            if not self.by:
                total_table = Table()
                total_table.fields = ['log_summary']
                total_content_parts = [
                    "你是 IT 运维和网络安全专家，下面是日志聚类后的关键信息摘要，请通盘考虑，输出中文总结和分析建议："
                ] + [row['summary'] for row in table.get_rows()]
                # 聚类总结内容已经是多行文本了，不能简单的用换行来合并 prompt，必须用明确分割符来指明每段文本
                total_content = "\n\n## 聚类摘要\n\n".join(total_content_parts)
                total_summary = self.llm_summarize(total_content, 'qwen')
                if total_summary is None:
                    logger.info("无法生成全局总结，请检查聚类总结内容。")
                total_table.add_row({'log_summary': total_summary})
                return meta, total_table
            else:
                return meta, table
```

注：qwen 的英文输出偏好微调一直被广泛吐槽。实验中发现哪怕 ernie 给出了中文总结，但因为包含一定比例的日志英文参数，qwen 就会输出全英文的总结！所以一定要在给 qwen 的 prompt 里明确写“**输出中文**”！

好了，方案就介绍到这里。我们可以看到，借助日志易 SPL 已有的能力，实现一套海量日志的 AI 总结，甚至连并发性能问题都考虑到位，只需要不到 200 行代码。有兴趣的读者，可以[访问 GitHub](https://github.com/rizhiyi/customcommand-contrib/blob/main/dpp.py)，获取完整代码，部署在您自己的日志易环境上（不要忘记替换自己的大模型 API-KEY），也体验体验～

