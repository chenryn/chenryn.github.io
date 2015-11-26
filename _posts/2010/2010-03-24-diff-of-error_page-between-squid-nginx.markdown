---
layout: post
title: squid和nginx的error_page差别
date: 2010-03-24
category: CDN
tags:
  - squid
  - nginx
---

nginx的error_page，有两个种办法。

一是直接error_page 502 503 504 = http://xyfunds.cdn.21vokglb.cn/index.htm;

二是error_page 502 503 504 =200 @fetch;然后location ~* @fetch {……}。

网上看到很多自定义error_page的方式，比如error_page 404 /404.php;把变量都传给php去分析处理；也可以在location里用if(){}做rewrite等等。

squid的error_page，可以有error_directory、error_map、deny_info三种方式。其中deny_info仅适用于ERR_ACCESS_DENIED一种情况；目前对于源站故障跳转，采用的是修改error_directory里html的meta；今天由nginx的方式想到采用error_map试试，于是写了如下php页面：
```php
<?php
switch ($_SERVER['SERVER_NAME'])
{
case 'www.xyfunds.com.cn':
header("Location: http://xyfunds.cdn.21vokglb.cn/index.htm");
break;
default:
echo $_SERVER['SERVER_NAME'];
}
?>
```
但测试结果，ERR的页面却是一片空白……在squid.conf,default中看到，原来<span style="color:#ff0000;">error_map只是返回定义页面的内容，header还是原先的。</span>
于是又想针对squid返回的%U，进行strtr()，然后再进行meta，如下：
```php
<?php
$urlarray = array('com.cn'=>'21vokglb.cn');
$urlrewrite = strtr("%U",$urlarray);
echo <META HTTP-EQUIV="refresh" CONTENT="0; $urlrewrite">;
?>
```
很可惜，测试结果是把这串字符直接显示在了页面上。
这两个结果让我很无语。如果说squid不支持php，那为什么它能识别出来上一个是修改header而不是页面内容所以不显示文本；如果说squid支持php，那为什么下一个又无法执行呢？

想对%U进行操作，难道非得到squid/src/errorpage.c里去修改么？C语言的字符串处理没有封装好的函数，真的好麻烦的说……


