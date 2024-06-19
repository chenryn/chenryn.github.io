---
layout: post
theme:
  name: twitter
title: cache驻留时间（三、Expires/Cache-Control）
date: 2009-11-20
category: CDN
tags:
  - cache
---

在谈cache的时候插入了上一篇回忆正则表达式的内容，是因为最近一个客户的古怪要求“url以/结尾或文件夹结尾的不能缓存”。

惯常的要求，大多有.*/$的缓存或者不缓存，这个文件夹不带/的结尾，可就没见过了。

思前想后，我觉得大概文件夹和文件的区别就是没有后缀名了吧。于是回忆了好一番正则表达式，最后写成下面那么一句：
```squid
acl test url_regex -i ^<a href="http://www.test.com/.*/[^.]*">http://www.test.com/.*/[^.]*</a>$
cache deny test
```
测试访问结果都是MISS/200——可惜还没高兴起来呢，赫然发现其header里写着：

    Expires: Thu, 19 Nov 1981 08:52:00 GMT
    Cache-Control: no-store, no-cache, must-ridate, post-check=0,
    pre-check=0
    Pragma: no-cache

敢情MISS不是我的acl起作用了，是人家web端早就定义好了……
转过头来，继续研究cache和header的关系。今天就看这个Expires、Cache-Control和Pragma：

* Expires 申明文件的过期时间，比如这里申明的是1981年——默认不缓存的设置一般就是1981年；

* Cache-Control 常见设定和说明见下图：
<img src="/images/uploads/cache-control.jpg" alt="" />
而且对于网民本地的浏览器来说，不同的操作，导致的结果也不同；

* Pragma
这个的说明不好找，大约是在HTTP1.0里使用的一种定义，我就见过no-cache一个选项，而且在HTTP1.1里，强烈警告不要使用这个标签。

概念都复述完了，然后是办法：squid可以在refresh_pattern段里使用各种选项把这些header一一忽略，当然，这些个个都是有违http精神的做法~~除了上期提到的ignore-reload以外，还有：ignore-no-cache ignore-private ignore-no-store ignore-auth ignore-revalidate(这些对2.6都要打补丁，更高版本集成了)。
这样的处理以后，关于客户端的网页缓存控制，就由web服务器对浏览器的If-Modified-Since进行判别控制了，可以说，除非是web方面有经验的做这方面的工作，不然的话，CDN上出错的概率很大……
最后提一句：文前提到的这个客户，后来我居然发现他有个文件夹目录是http://www.test.com/update/v2.4，无语了，天知道还有什么别的稀奇古怪的目录命名……

