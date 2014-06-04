---
layout: post
title: 直接从 elasticsearch 获取数据进入 skyline 异常检测
category: monitor
tags:
  - python
  - elasticsearch
  - skyline
---

这几天搭建 elasticsearch 集群做日志分析，终于有机会可以实际跑一下 skyline 的效果。不过比较麻烦的事情是，skyline 是一个比较完备的系统而不是插件，要求我们把数据通过 msgpack 发过去存到 redis 里。这是个很没有道理的做法，早在去年刚看到这个项目的时候我就在博客里写下了愿景是应该用 elasticsearch 替换掉 redis。等了这么久没等到，干脆就自己动手实现。修改后，skyline 其余的程序完全可以直接扔掉，只留下这一个脚本定时运行就够了：

<script src="https://gist.github.com/chenryn/309bed093f6a7084c855.js"></script>

其实改动的地方很少~这让我愈发不理解 etsy 原来那样做的理由了。

这里面主要就是拼了一下 elasticsearch 的 `date_histogram` 类型的 facet 请求，获取最近 1 个小时的每 5 分钟统计值构成的时间序列数据。然后发给前面那些检验算法。

之前用过 js 和 perl 的 elasticsearch 客户端，对象封装的都蛮细的，而 python 的这个客户端写起来就非常像 curl 命令了。

如果要推广用，把里面这个 `code.504` 提出来做一个可配置项就行了。

