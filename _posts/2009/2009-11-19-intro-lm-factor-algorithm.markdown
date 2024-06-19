---
layout: post
theme:
  name: twitter
title: cache驻留时间（二、LM-factor算法）
date: 2009-11-19
category: CDN
tags: 
  - cache
---

好吧，满足某人的好奇，花开两朵，各表一枝了。
今天又看到关于LM-factor的另一种说法，特摘录如下：
<img src="/images/uploads/lm-factor.gif" alt="" />
上面这张图来自于《Squid.Definitive.Guide》第七章，对squid的LM-factor算法作出了一个很直观的描述。
请注意这张图的起始时间坐标：Last-Modified，这个是由squid读取的原始web数据所规定的。
然后就是Date，这个是原始数据进入squid的缓冲的时间。
最后就是Expires，这个就是原始数据在squid中的缓冲过期时间。
可以很容易的得出结论，对于LM-factor算法来说，原始数据在squid中的缓冲时间为
(原始数据进入squid的缓冲的时间-原始web数据所规定的Last-Modified时间)*percent
所以，我们可以郑重得出结论，在squid的refresh_pattern设置中，percent与Min、Max两个值是完全没有关系！
最后总结一下，对于squid来说，缓冲的数据在cache中的存活时间是这样决定的：
如果有定义refresh_pattern：只要满足以下两个条件之一，缓冲对象过期
缓冲对象在squid的cache缓冲的时间大于refresh_pattern定义的max
缓冲对象在squid的cache缓冲的时间大于(原始数据进入squid的缓冲的时间-原始web数据所规定的Last-Modified时间)*percent
用编程语言来描述，就是
if
((CURRENT_DATE-DATE)
elif
((CURRENT_DATE-DATE)/(DATE-LM_DATE)
elif
((CURRENT_DATE-DATE)>max){STABLE}
else{STABLE}


