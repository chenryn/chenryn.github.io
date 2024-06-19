---
layout: post
theme:
  name: twitter
title: squid加载tcmalloc性能优化测试(编译)
date: 2010-02-04
category: squid
tags:
  - squid
  - tcmalloc
---

话接上文，同一组LVS下，昨天采用重编译方式部署了另一台squid服务器。同样跑上一天，再次对比一番。今天流量比上回稍微少些，未加载的服务器cacti监控截图如下：
<img src="/images/uploads/62d80b5eh73140310b076690.jpg" alt="" title="cpu" width="573" height="259" class="alignnone size-full wp-image-2565" />
CPU占用率
=====================
<img src="/images/uploads/62d80b5eh73140316c9a2690.jpg" alt="" title="loadavg" width="569" height="254" class="alignnone size-full wp-image-2567" />
负载
<hr />
同时，重编译过后的squid服务器监控截图如下：
<img src="/images/uploads/62d80b5eh7314031cd5b3690.jpg" alt="" title="cpu-new" width="572" height="261" class="alignnone size-full wp-image-2568" />
CPU占用率（那个尖峰是我运行了一下lsof确认是否加载，lsof这个命令真是大杀器，少用……）
=====================
<img src="/images/uploads/62d80b5eh731403230ce5690.jpg" alt="" title="loadavg-new" width="570" height="258" class="alignnone size-full wp-image-2569" />
负载

这么一对比，效果马上就出来了。难怪官方建议要用编译加载的方式呢~~~


