---
layout: post
title: squid源站故障转向（终结篇）
date: 2010-03-28
category: CDN
tags:
  - squid
  - C
---

因为这么一个想法，我陆陆续续的把squid很多功能都理了一遍，今天终于打算写个不完美的终结篇。而就在写这个终结篇的同时，公司里也已经开始把这批别扭的客户改往nginx平台加速了。

总结这批客户的跳转要求，其实格式都比较统一，大抵就是*.abc.com(.cn)坏了就转到abc.cdn.21vokglb.cn。在3月24日的博文最后，已经有了一个思路——既然无法执行php的header(Location)和strstr(%U)，那么就干脆在squid的src里对%U进行操作好了。

squid-src/errorpage.c中关于%U的注释是：

    U - URL without password

相关语句是：
```c
p = r ? urlCanonicalClean(r) : err->url ? err->url : "[no URL]";
```
只要把url按"."分割，然后取出第二个域abc，就可以在html代码中给它加上跳转后的url了——这一步也能在src里完成，不过以后不好修改了，虽然现在这样子的定制性也强不到哪去~
从大二到现在无数年了，c已经属于忘到冥王星外的东东，于是一个一个的翻c的字符串函数，从strstr、strchr、strcat、strtok、strsep到最后终于发现sscanf。只要在src/errorpage.c的588行下加这么一句话就可以了：

```c
587     case 'U':
588         p = r ? urlCanonicalClean(r) : err->url ? err->url : "[no URL]";
589+      sscanf(p,"%*[^.].%[^.]",p);
590         break;
```
然后编译安装，一路通过没有问题~~启动squid服务，测试一下%U吧~
先把ERR_ACCESS_DENIED内容修改如下：
```html
<HTML>
<BODY>
<head>
<META HTTP-EQUIV="refresh"   Content="0;URL=http://%U.cdn.21vokglb.cn/index.htm">
</head>
</HTML>
```
然后在squid.conf中增加对自己本机的访问控制如下：
```squid
acl test src 222.62.104.189/255.255.255.255
http_access deny rao
```
squid -k reconfigure生效，访问一下www.xyfunds.com.cn，果然跳转到xyfunds.cdn.21vokglb.cn/index.htm啦~~
完毕。
虽然最终还是没能达到任意定义跳转url的目标，不过就本身的出发点来说，还是完成了需求。这也是我N年来第一次重新看C，也是第一次修改squid代码，虽然只加了一句~~~不过意义还是有滴，晚上吃个鸡蛋自我犒劳一下咯。

