---
layout: post
title: 忽略大小写（squid）
date: 2010-03-09
category: squid
tags:
  - squid
  - perl
---

在配置squid.conf的refresh_pattern或者url_regex的时候，我们习惯性的都会加上一个options：“-i”，用于忽略大小写。
前不久配置nginx.conf的location时，也用上了~*忽略大小写。
但是这个“忽略大小写”，其实只是整个请求处理流程中部分过程——配置规则的匹配过程——中的忽略。
在使用了这些options以后，一个http://www.test.com/a.htm和另一个http://www.test.com/A.HTM请求在到达squid/nginx的时候，会统一无视大小写的进行规则匹配，然后可能proxy_pass到oringin获取数据；接下来有两种情况：
oringin是windows主机，不区分大小写，返回200数据，缓存下来——分别是a和A两份！
oringin是类unix主机，区分大小写，返回一个正确的200，一个错误的404……甚至可能两个都404~~
（根据测试，完整的url中，host是不用区分大小写的，url_path里的大小写才有影响）
如果要让同样的内容就缓存一份数据，我想就只能在squid/nginx内核在处理url之前，将url的大小写问题处理掉。

squid可以url_rewrite_program，perl很简单的lc()即可，如下：
{% highlight perl %}
#!/usr/bin/perl -w
$|=1;
while(<>){
    my @X=split;
    my $uri=lc($X[0]);
    print($uri);
}
{% endhighlight %}

nginx的http_perl_module，看起来像是做这个的，不过官网上声明说，里面的perl如果执行太多的查询类操作（比如DNS域名解析、数据库操作等），很可能就把nginx的worker-process跑挂了……；且启用这个模块的话，就不能reconfigure，否则可能内存溢出云云……
