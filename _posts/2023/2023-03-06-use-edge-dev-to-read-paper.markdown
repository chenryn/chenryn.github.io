---
layout: post
theme:
  name: twitter
title: Edge Dev 用法：让 ChatGPT 读论文
category: LLM
tags:
  - ChatGPT
---

上一篇介绍了 BLIP2 多模态模型没多久，今天又有多模态领域的大新闻，微软发表了一篇论文，介绍自己的Kosmos-1 多模态模型。不过论文没提供在线 demo 可用，只能直接阅读论文了。

我们都知道，ChatGPT 可以做文本摘要，快速总结中心思想。普通的文本， copy-paste 内容过去也挺方便，但 PDF 论文，没那么简单复制粘贴。这时候就需要 Edge Dev 浏览器出马了。

在浏览器地址栏中输入 https://www.microsoftedgeinsider.com/en-us/download/dev，打开 Edge Dev 官网，页面首屏正中间的位置就可以点击下载安装包并进行安装了。这块不作具体介绍。让我们直接进入使用环节。

安装完成以后，右上角会多出一个 Bing Chat 图标，点击就可以直接在侧边栏使用 ChatGPT。和在 bing.com 搜索引擎里使用相比，Edge Dev 里的 ChatGPT 最大优势是默认用当前打开的标签页网页内容作为聊天背景材料。因此，你可以免去复制粘贴的手工操作、免去字数超标的担心，直接基于当前页面开聊。

加上 Edge 浏览器一直以来对主流文档格式都有超强的阅读支持，用来读文章，简直犀利无比。

打开原始论文以后，怎么让 ChatGPT 帮我们读论文呢？

我们都知道，写论文、读论文其实一般是有套路的，内容大体都分为：内容摘要、场景问题、创新点、具体方法、评估结果、总结展望。

考虑到 ChatGPT 的输出字数有限，让他一口气全部解读完不太合适。但 Edge Dev 又限制了一次 chat 最多 6 次问答。所以，就按这个步骤来问吧：

1. Don't search the Internet, summarize this article according to what method, what technology is used, and what effect is achieved in this paper?
2. Don't search the Internet, what are the advantages of their solution compared with the previous ones, and what problems did they solve that the previous methods could not solve?
3. Don't search the Internet, please describe the main procedure of the method in detail in combination with the content of the Method section. Please use latex to display the key variables.
4. Don't search the Internet, combined with the Experiments section, please summarize what task and performance the method achieves? Please list specific values according to this section.
5. Don't search the Internet, please combine the Conclusion section to summarize what problems still exist in this method?

注意：**开头这段 "Don't search the Internet" 是 Edge Dev 单独定制的 prompt，如果你不打算让 ChatGPT 去搜互联网，这段话，连字母大小写必须原封不动的照抄！哪怕你打算用中文问 ChatGPT，也得先用英文抄这段。**

但如果你打算引入其他知识进行对比，那就刚好相反，不写这句 prompt 才行。

用法介绍完毕，现在，让 ChatGPT 来替我们总结一下 Kosmos 论文，并跟 BLIP2 对比一下吧：

![](/images/uploads/2023-03-06-use-edge-dev-to-read-paper_image_1.png)

ChatGPT 通过互联网搜索获取 BLIP2 知识后，总结对比给出了结论：Kosmos 比 BLIP2 多了“非语言推理”的支持。不过“非语言推理的任务”在论文里指的是什么？还得 ChatGPT 再解释一下：

![](/images/uploads/2023-03-06-use-edge-dev-to-read-paper_image_2.png)

ChatGPT 立刻给出了在论文中具体的用例，“非语言推理的任务”在论文中是指 Raven IQ test。ctrl+F 打开页面搜索，跳转到 Raven IQ 位置，就看到配图了。

作为普通用户，两三次问答，就了解完微软 Kosmos 论文讲什么，有什么特色。Edge Dev 浏览器在这方面，真是大大提升了生产力。
