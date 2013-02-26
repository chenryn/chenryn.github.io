---
layout: post
title: mod_perl处理流程图一张~
date: 2010-05-22
category: web
tags:
  - perl
  - apache
---

在<a href="http://www.fayland.org/journal">http://www.fayland.org/journal</a>上看到一张图，感觉很舒服很明白，转帖过来。
<img alt="" src="http://www.fayland.org/journal/img/http_cycle_all.gif" />
<hr />
其实mod_perl官网有也有这个类似的图，不过没这个pp~~

总的来说，mod_perl不同的指令，就是分别插入到这个圆圈上的标签位置，完成不同的作用。

比如说，PerlTransHandler可以做url_rewrite；PerlHeaderParserHandler可以判断request_header；PerlAccessHandler可以做访问控制；PerlAuthenHandler可以做用户验证；PerlLogHandler可以记录日志。

如果perl程序return的是Apache2::Const::OK，那就直接结束这个圆环，进入之后apache该干的事情去；如果是Apache2::Const::DECLINED，那就表示这个handler正常完成了，继续沿着圆环走吧~

 针对每个handler的具体可配置，还是看官网吧：<a href="http://perl.apache.org/docs/2.0/user/handlers/http.html" target="_blank">http://perl.apache.org/docs/2.0/user/handlers/http.html</a>

之前我就是这个地方犯错了，在httpd.conf里指定的accesshandler，程序却想完成rewrite的功能，结果一直报404……
