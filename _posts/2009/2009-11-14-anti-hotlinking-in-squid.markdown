---
layout: post
title: squid防盗链配置
date: 2009-11-14
category: squid
---

做网站的，谁愿意自己辛辛苦苦的成果就被别人轻松转载，如果是文字的，一般也就禁鼠标右键，再没什么好办法（当然，名人好打官司另说），但如果是图片，影音的文件，大可以利用http协议的header信息进行控制，这就是大多数web服务器日志要记录的referer。
公司新进一测试客户，就要求CDN方配合做防盗链。

公司自然有规范，直接ctrl+c、ctrl+v就搞定。但这些句子，还是值得细细研究一下的。
相关语句如下：
```squid
acl test_domain dstdomain .test.com
acl null_referer referer_regex .
acl right_referer referer_regex -i
^http://test.com ^http://.*.test.com
http_access allow test_domain !null_referer
http_access deny test_domain !right_referer
```
第一关键点，是第一行的那个“.”，“.”匹配的是除了“n”以外的任何一个字符。那么!null_referer也就是“n”，也就是说第一条access定义的，是允许referer为空行；

第二关键点，是access的“!”，“!”就是非，那么!right_referer定义的就是一切除了test.com以外的域名，也就是说第二条access定义的，是不允许所有其他网站。

这样的结果，也就是只有从test自己的网站，或者直接在浏览器地址栏里输入完整url，才能看到文件（linux上常用的wget、curl，默认的referer也是空，所以也可以。我又试试迅雷，其referer也是空，那么估计下载工具也都是这样）

（比较奇怪的一点是：squid的日志里，空不显示为“ ”，而是“-”，很能迷惑人呀！）

于是我想到新浪和百度呀这些博客之间转来转去的图片，一般都显示一个空图，但点开来（或许还要再刷一次）也一样能看。可见防盗链都是这么做的。

如果真就狠到了连直接url查看也不让，那就把null_referer的定义删除掉，自然也就可以了……

试到这里，发现另一个问题：nagios的监控，一般也是空referer的，如果真这么狠的要求，这个监控也得改了。
因为不管是curl还是wget，都可以伪装referer。
两个的伪装语法分别是：
curl -e "http://www.test.com" -x $squidip:80 http://www.test.com/test.gif
wget http://www.test.com/test.gif --refer="http://www.test.com" -e "http_proxy=$squidip"

我对nagios不熟，不知道里面具体是用什么去check的，大概也差不离吧？
最后，像新浪百度这样的盗链显示图片怎么做的？也就是一句话的事，如下：
```squid
deny_info http://www.test.com/你盗链啦.gif
right_referer
```
