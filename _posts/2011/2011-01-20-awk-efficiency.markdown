---
layout: post
title: awk的效率
date: 2011-01-20
category: bash
tags:
  - awk
---

偶然和某人谈到日志处理。最简单常见的需求，日志中访问量最大的前十个IP及其访问次数。

最常见的shell命令：cat access.log | cut -d ' ' -f 4 |sort|uniq -c|sort -nr|head

我最常用的awk命令：awk '{a[$4]++}END{for(i in a){print a[i],i}}' access.log | sort -nr | head

对方表示上一种速度最快，而我说是下一种。

最后找到一个13G大小的access.log，用time命令分别检测命令用时。结果处理一个13GB的日志，shell花了13分钟，awk花了1分半钟……
