---
layout: post
title: client-cache-origin之间的session问题
date: 2010-01-09
category: CDN
tags:
  - squid
---

昨天，突然接到某客户的邮件，表示他们质疑我们cache对其多originserver的轮询不均等，以至于影响到网站的访问。
听起来不是什么难题，把服务器上的DNSCache进程中止掉，不就能平均轮询了么？可是操作完成后，客户依然不认可……于是开始细细探讨具体的错误问题所在。
原来实际情况是这样：点击其网站的回复、收藏等动态页面时，时常会弹出错误页面。对这个错误页面，客户的解释是“session状态CDN加速未保留”。
由此解释，我觉得cache上的问题恰恰相反，正是因为均等轮询了导致的。而客户其他一些单源的域名服务正常，也证明了这点。
上cache服务器查看配置，使用的默认keep-alive设置，也就是对client和origin都开启了keep-alive，默认时间为2min。但实际上并没有起作用。在测试中，可以看到这样的日志：

    [rao@localhost ~]$ tail access.log|awk '{print $4,$6,$7,$9,$10}'
    TCP_IMS_HIT/304 GET http://a.b.com/wentiyongpin/11106917.html NONE/- "http://a.b.com/wentiyongpin/"
    TCP_MISS/200 GET http://a.b.com/RelatedUserInfo.aspx?nickname=shunfataiqiu DIRECT/1.2.3.4 "http://a.b.com/wentiyongpin/11106917.html"
    TCP_MISS/200 GET http://a.b.com/postcomment/Reply.aspx?info_id=11106917 DIRECT/1.2.3.5 "http://a.b.com/wentiyongpin/11106917.html"
    TCP_MISS/302 POST http://a.b.com/postcomment/Reply.aspx?info_id=11106917 DIRECT/1.2.3.4 "http://a.b.com/postcomment/Reply.aspx?info_id=11106917"
    TCP_MISS/404 GET http://a.b.com/nf3.aspx?aspxerrorpath=/postcomment/Reply.aspx DIRECT/1.2.3.4 "http://a.b.com/postcomment/Reply.aspx?info_id=11106917"

由日志可见，在进入post页面（此时方式还是GET）时，session的origin从1.2.3.4轮询到了1.2.3.5，而填完了回复内容，点击提交（此时方式改成POST）时，origin又轮询回了1.2.3.4——而此时1.2.3.4上并没有相应ID的session存在——于是页面被302重定向去了错误提示页面，也就是下面的404。

这种情况，主要来说，还是客户网站本身的架构问题。简单点，只用一个origin；复杂点，在多台webserver与后台数据库之间建共享连接池。保证session调用正常。

但在客户修改origin之前，cache本身能不能作出一定的改变呢？能。放弃使用dns查询，而采用squid本身的peer功能，就能搞定它，配置如下：
{% highlight squid %}
#Parent
acl ParentDomain dstdomain a.b.com
cache_peer 1.2.3.4 parent 80 0 no-query no-netdb-exchange originserver sourcehash
cache_peer 1.2.3.5 parent 80 0 no-query no-netdb-exchange originserver sourcehash
cache_peer_access 1.2.3.4 allow ParentDomain
cache_peer_access 1.2.3.5 allow ParentDomain
always_direct allow !ParentDomain
#Parent end
{% endhighlight %}
用的sourcehash参数，相同的clientIP，使用相同的originIP，多好的loadbalance呀，更巧的是这个option，正好是squid2.6.STABLE21能用的，连2.7都没有，哈哈~~reconfigure后的正常日志如下：

    [rao@localhost ~]$ tail access.log|awk '{print $4,$6,$7,$9,$10}'
    TCP_IMS_HIT/304 GET http://a.b.com/wentiyongpin/11106917.html NONE/- "http://a.b.com/wentiyongpin/"
    TCP_MISS/200 GET http://a.b.com/postcomment/Reply.aspx?info_id=11106917 SOURCEHASH_PARENT/1.2.3.4 "http://a.b.com/wentiyongpin/11106917.html"
    TCP_MISS/200 GET http://a.b.com/RelatedUserInfo.aspx?nickname=shunfataiqiu SOURCEHASH_PARENT/1.2.3.4 "http://a.b.com/wentiyongpin/11106917.html"
    TCP_MISS/200 POST http://a.b.com/postcomment/Reply.aspx?info_id=11106917 SOURCEHASH_PARENT/1.2.3.4 "http://a.b.com/postcomment/Reply.aspx?info_id=11106917"
    TCP_MISS/200 GET http://a.b.com/ SOURCEHASH_PARENT/1.2.3.4 "-"
    TCP_MISS/200 GET http://a.b.com/zufang/ SOURCEHASH_PARENT/1.2.3.4 "http://a.b.com/"
    TCP_MISS/200 GET http://a.b.com/ad.ashx?ad=ad&url=http://a.b.com/zufang/&alias=zufang&childalias=zufang SOURCEHASH_PARENT/1.2.3.4 "http://a.b.com/zufang/"

整个访问中，回源IP一直都是1.2.3.4，而且POST不再是302转404，而是200了~~


