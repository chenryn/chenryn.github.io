---
layout: post
theme:
  name: twitter
title: 让squid访问日志显示完整url
date: 2009-11-21
category: squid
---

一大串的header结束了，从上篇开始回到squid.conf本身的设置上来。

这里说一个小东西，一般用不上，但难保哪天就用了：

我们在access.log里，常看到很多url只显示到?，之后的东西就都忽略掉了，这一是为了醒目，反正都不缓存，显示干嘛；二是为了保密，说不定有些网站的GET就直接把什么秘密信息都明文传输呢？

但有时候特殊情况要求我们调试squid，比方说之前提到过的非得缓存?，却又没有提前告知，临时想要自己找完整url，怎么办？

其实有办法，squid配置中有一个strip_query_terms，就是管这事儿的。默认是on，只要改成off，就可以了~~嘿嘿，干坏事的机会到来了……
