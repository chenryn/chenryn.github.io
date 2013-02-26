---
layout: post
title: cache驻留时间（四、If-Modified-Since）
date: 2009-11-21
category: CDN
tags:
  - cache
---

话接上回If-Modified-Since，当squid开启reload_into_ims on之后，no-cache头会在在浏览器上被转化成If-Modified-Since标识返回给web服务器。从整体架构考虑，因为squid上已经破坏了http协议的规定，那么web端就必须主动承担对网页过期的识别管理工作。嗯，要是所有的网站都能从一规划开始就这么搞，俺们干CDN的可就轻松了~~~

下面是一段php代码，简单的实现对If-Modified-Since标签的过期管理：
{% highlight php %}
<?php
$headers = apache_request_headers();
//读取整个header信息
$client_time = (isset($headers['If-Modified-Since']) ?
strtotime($headers['If-Modified-Since']) : 0);
//判断header信息是否包含If-Modified-Since标签，有则转换其时间为Unix格式，否则退出这段定义
$now=gmmktime();
//web服务器的系统时间，为处理方便转换为GMT
$now_list=gmmktime()-60*5;
//五分钟前的时间
if ($client_time<$now and $client_time
>$now_list){
//判断浏览器时间是不是在当前的五分钟内
header(’Last-Modified: ‘.gmdate(’D, d M Y H:i:s’,
$client_time).’ GMT’, true, 304);
exit(0);
//判断为真，则给header加上时间为浏览器时间的Last-Modified标签，告知浏览器网页未过期
}else{
header(’Last-Modified: ‘.gmdate(’D, d M Y H:i:s’, $now).’ GMT’,
true, 200);
//否则给header加上时间为服务器系统时间的Last-Modified标签，告知浏览器网页过期，重新下载
}
?>
{% endhighlight %}
这做一个范例，如果用其他的标签定义来控制过期，照葫芦画瓢就行了。比如用Expires控制，就写

    header('Expires: ' . gmdate ("D, d M Y H:i:s", gmmktime() + 60*5). " GMT");

题外话一句，php中关于date的函数很多，各种的格式不同，小心使用。好比这个新浪博客，就有一个小问题，如果你半夜写博客，过了零点以后发表，会提示错误；甚至如果你原先是10点发表的，隔了几天半月的哪天下午14点来修改保存，也会提示错误。非得要你改成当前分钟之前才行……

