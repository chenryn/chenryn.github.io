---
layout: post
title: ChatGPT 初尝试(3): 云原生改造咨询专家
category: LLM
tags:
  - ChatGPT
  - 云原生
---

我们都“知道” ChatGPT 可以根据互联网的数据生成大段的文字，AIGC 在自媒体上已经玩的不亦乐乎。那在相对专业的细分领域，ChatGPT 能起到什么作用呢？能给出什么回答，怎么问才能得到好的回答呢？

这次我尝试从一个业界其实也还没有定论的话题，开始问答。这就是：云原生转型。“云原生”是一个很热门、但又很模糊的 IT 概念。CNCF 的说法基本是以K8S为核心，国内的腾讯、华为则各有自己的2.0、3.0 版本阐述。

现在，让我们假装自己是个啥都不懂的小白，开始提问。

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQgRTiaTY0lBiaxQCV6QwJrCxpszdbZ9oicxAVC6GBlMQvoTtkufhrhe3Pg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

第一步结论出来了：**只用云主机，自己部署，是“云托管”，不是“云原生”**。这里再次强调了要充分利用云平台的特性。那么好，进一步追问：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQNAQFtn7fXWadh03SKzl41JxJcKWwuNz1TCzL48DYUpcjHia0AhQZWTQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

第二步结论还是很坚定：**只用云主机和云数据库，也不是“云原生”**。这里ChatGPT 理解了提问的我对高可用性直观理解为数据库高可用性了，所以也不再强调这个词，于是换了一个说法：不能只用一个服务。但这个说法不够清晰啊，于是要求他说清楚一点，到底是啥服务：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQYPFicyoYD75E5AIlqFDtXibDZWFyM50teuMNzyQhClFB4ClL8xRm9NWg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

这次 ChatGPT 没能理解“服务”的含义——其实跟我们所有人一样，中文里服务、应用、系统、平台、模块这几个词的含义太模糊了。

于是我及时点了 stop，打断了 ChatGPT 的生成，补充清晰“组件”这个定义。对，就跟我们咨询乙方时毫不留情打断对方一样。这次，ChatGPT 就给出非常具体的建议了：容器、函数、数据库、自动化部署几个服务的具体产品名称都给出来。

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQLNNKUzJsIKWQWB0nmAYu2zygmINE4ykOrEgLbcy8hbqxWJ6ibr7TFMg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

为了防止自己理解错误，我再按自己的理解重复确认一遍。ChatGPT 还很严谨的强调了一下这是个大进步，但不够。

不过我已经听不进去了，我要赶紧转型成云原生！这里最不熟的就是 codedeploy 了，第一次听说啊。继续给我介绍吧：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQwpb5MgPP29zcyeC9QxhwHWVGulBRR9C3qB8zPHYoDn7qJwMAiavLvxw/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

看起来不是太难。不过又有新概念被提及了，还得问清楚：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQVgQIkVVPcbCVfs29yI6JRHvByagSzUWYrBRKiaeF0KlsSfj6q5UDxtg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

再看看刚才的介绍，codedeploy 也能部署到 EC2 啊，那我可以不做这个迁移？问问看：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQzhjxcwkwCia99ibJb6xibGSfjq9bbYnsb3NcozEMLkeaDZGTgqqgM715g/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

万万没想到，ChatGPT 还很有原则，再次强调不行：**没有微服务和容器化的就是不算云原生！**看来我只能勉力为之，开始规划自己的代码重构任务了：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQt6x96sP5s92K1Hou5epCfZDrVsqmjQ8DE8QAJGvkRwsQZ1hXB1uia0Q/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

看起来这个回答不是很明确，换成任何一个 XXX 应用，回答都能套这个模板。还是得从具体项目入手，换个问法：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQwCeogJhh7Vkib5LNcuhsWoU85jOJPxdeBRzjRxc0pHzZTCESmnYzP1g/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

换了两个角度，成功得到了 wordpress 如果要微服务化，可以怎么拆分。不过一口气搞动静可能太大了，先试点哪个呢：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQbkP424981JLQAmL0WPUQIgOMJQOqvw0qn4EPH5icly9FnscWwXXA85Q/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

ChatGPT 又提到一个新东西了，这个叫 Laravel 的框架不知道对我们云原生转型有没有用？问问看：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQ9qTqpSwDL05hfB3lG3vAWfP1tZpVDrib7h95hynnqUkyCFfJib6r5SLg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

看来确实是可以通过 Laravel Passport 来做我们云原生改造的第一步试点啊。那学起来吧：

![](https://mmbiz.qpic.cn/mmbiz_png/tNjHEwGJhqGuop2EE6pbzWLVGU9IQGZQNgXiaweqv2a8LH22MC15T4AKP8bTVJlGELH14Y4AzC4dYPRNTYYF5TQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

这次转型咨询到这就差不多结束了。从一个非专业 PHP 研发的角度，感觉 ChatGPT 完全能说服我。不知道读者朋友们，能从这些回答中，挑出什么错误呢？私信告诉我吧~
