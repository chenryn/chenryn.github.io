---
layout: post
theme:
  name: twitter
title: wordpress部署时碰到的php小问题~
date: 2010-02-25
category: web
tags:
  - php
---

看到windows live writer也支持wordpress，感觉这个博客系统确实流行，决定自己也试一把~install时，出了点问题，选择好sqlname和user、passwd信息后，另存为wp-config.php，next生成管理账户和密码的页面，居然顶上出现了“Warning: Cannot modify header information - headers already sent by ...”，无视之，记下随机密码，下一步login——彻底废了，整个页面都是这个warning提示~~

百度了一下这个问题，原因真是多种多样，php不支持UTF8的BOM、php的output_buffering没打开、php中setcookie的使用限制等等，不过我这是从wp自己的页面文本框里复制出来的东东，应该问题不大才对。结果回去一看，原来是最最简单的问题：<?php...?>后面，多了一个空行！！

ctrl+a后ctrl+c复制文本，一般都会多出来一个\r\n，insert进vi的时候自然也就多了一个空行，不巧的是，在include或者require的php里，如果首尾有空行的话，程序就很有可能出问题…………

del掉这个空行，退出刷新页面，OK！

