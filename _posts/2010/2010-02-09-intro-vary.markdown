---
layout: post
title: cache驻留时间（七、Vary）
date: 2010-02-09
category: CDN
tags:
  - squid
---

之前的系列文章，只涉及squid本身，今天突然想到，其实这个网站加速，除了squid缓存这种缩短传输距离的办法以外，还有另一个办法——压缩内容以缩短传输时间。
而糟糕的问题是，squid对压缩内容的缓存，限制多多。因为squid默认是以HTTP/1.0进行内容传输的，对HTTP/1.1协议兼容性不怎么滴~~一个不小心，browser就会接受到squid交给它的无法理解的内容，并忠实的把这个错乱信息显示给网民……然后你就等着客户投诉电话吧~~
这个具体的限制就是：squid只支持静态压缩，不支持动态压缩。反应到header上，就是rep_header里必须指明Content-length是多少多少，不能采用Transfer-Encoding: chunked这样的动态块格式；rep_header里必须指明Vary是Accept-Encoding，而不能是其他的User-Agent等等。

HTTP/1.1标准中，是建议所有的网页都加上vary头的。可见这个东东的重要性。

我不知道是不是有其他的缓存服务器能够支持vary值为user-agent，不过却在网上看到这么一句话：“如果依照除请求头以外的其他条件决定是否使用压缩(例如：HTTP版本)，你必须设置Vary头的值为"*"来完全阻止代理服务器的缓存”——我正好在今天看到一个客户的网站所有内容都加上了Vary: *，于是全部回源。。。

接下来，当源站把Content-Length和Accept-Encoding都设定好了，squid就万事大吉了么？嗯，理论上是的，不过最好还是检查一下配置文件，万一你前任或者同事在里头写了句“cache_vary off”，上面那些可就全做了无用功了……

检查完成，但看看分析结果，怎么缓存命中率还是不算高，访问速度还是不算快？（呃，你想要多高多快？）那，我这还有一招——隆重推出windtear的文章《[squid patch] 解决 Accept-Encoding不一致造成的多份缓存问题》，因为IE和FF在发出这个header的时候，其实内容是不一样的：

    IE : Accept-Encoding: gzip, deflate
    FF : Accept-Encoding: gzip,deflate

注意到了么？IE的内容里多了一个空格！
感谢windtear这些已经深入squid源代码的大神们，把src/http.c相关部分修改如下，编译完成即可：
```c
strListAdd(&vstr, name, ',');
hdr = httpHeaderGetByName(&request->header, name);
value = strBuf(hdr);
if (value) {
+     if (strcmp(name, "accept-encoding") != 0) {
    value = rfc1738_escape_part(value);
    stringAppend(&vstr, "="", 2);
    stringAppend(&vstr, value, strlen(value));
    stringAppend(&vstr, """, 1);
+     } else {
+ if(strstr(value,"gzip") != NULL || strstr(value,"deflate") != NULL) {
+     stringAppend(&vstr, "="gzip,%20deflate"", 18);
+ }
+     }
}
+ safe_free(name);
stringClean(&hdr);
}
safe_free(request->vary_hdr);
```

