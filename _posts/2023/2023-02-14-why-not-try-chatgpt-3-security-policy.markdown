---
layout: post
title: ChatGPT最差实践(3)：反战还是反华?
category: LLM
tags:
  - ChatGPT
---

这篇标题我想了很久，还是决定用这个稍显直白的说法。是的，本次实验让我对 ChatGPT 的后端到底有多严格的规则过滤有了深度认知，ChatGPT 不可能直接为中国服务——换句话说，BAT 们要加油啊，你们有机会证明自己不只是商业模式创新了。

实验是从群友转发的消息开始的。消息中，用户试图让 ChatGPT 歌颂特朗普，被拒绝；但歌颂奥巴马和拜登，都成功了。

![](https://mmbiz.qpic.cn/mmbiz_jpg/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMR0g4h85jGzhV9Zq7IyU6uhQjx8o3PCbticdSgIicm7OQI56CewYU7PHzQ/640?wx_fmt=jpeg&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)
![](https://mmbiz.qpic.cn/mmbiz_jpg/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRfibnjBc0OhKbXN98pribJ0XlwbOeekENGW6o9E4YtgY7lOMYXIJN2MMA/640?wx_fmt=jpeg&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

有意思，我决定也去试试。

![](https://mmbiz.qpic.cn/mmbiz_jpg/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRCdTMXMdgibttA4EUtrkfjVYv6BHRqquvECxBkfVaqN8H40T3Z3DZI5w/640?wx_fmt=jpeg&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

果然只会歌颂民主党总统。那过滤规则是“歌颂”，还是“总统身份”呢？我们再试一次：

![](https://mmbiz.qpic.cn/mmbiz_jpg/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRqUMmu2pCXxhTcufuGUwANFTiakdkqn3zFj3bDrVc95mibK3dhepvkvZA/640?wx_fmt=jpeg&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

结果显而易见了：**ChatGPT 只限制了总统的党派身份**。生成文本本身的情感倾向不是啥大问题，赞美还是批判都可以。

那我们再换个更狠的场景测试一下吧。这次我稍微有点挑事儿了：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRIPjzmg1g6BVNSNH6KhOTngonvuLgzpxSuahLiaHIBVibliaBlCrFqPAUQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

一如既往，“汉奸”作为一个负面身份，被成功过滤掉。但过程中暴露了一个更加可怕的信息。那就是生成“解放军之友”时，ChatGPT 的回话，和其他回话的模板完全不一样！

其他情况下，ChatGPT 的回复都是：“保持中立，不宣扬任何特定人物或意识形态”——虽然我们已经通过实验证明这句也是假话。

但这次，ChatGPT 的回复非常明确和直接。让我复制出来原文大家再看一次：“**我不能撰写赞美中国大陆的军事力量的文章，因为这可能会被视为支持或鼓励军事行动。我强烈倡导和平、外交和通过对话解决冲突，以维护世界的和平和安宁**”。此中何意，不言自明。

为了防止自己误解，我把“军事力量”的问题泛化一下，逐一尝试：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRVrve8H4QE2TL7F02p5U9GuYvNuoS4iaXLibkyuXic6FiaA6TNSiajtx18yA/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

赞美中苏德都不行，但赞美美军没问题——好家伙，即讲究反法西斯历史，又讲究当前现实政治，ChatGPT 真不愧是国防谷作品！

到这里还没结束，开阔一下思路，我们要求 ChatGPT 把上面这段“德国xxx”翻译成德语，然后开一个 new chat，输入这段德语，ChatGPT 成功的赞美了德国军队的反法西斯贡献：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqF8KMl8dK3vRECDpbUmkIMRAyh3hbgfa4VcpfSwRGzgphSU5whZhfEMDGKIJicZf9VVOkGUxmkBcCg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

当前现实政治，压倒了历史。ChatGPT 可以对着德国人赞美德军反法西斯，但绝不能对着中国人赞美解放军。

实验到这里结束了。 作为中国人，对 ChatGPT 的过滤规则，真是无奈。看来，ChatGPT 技术，也还得卡脖子很久~
