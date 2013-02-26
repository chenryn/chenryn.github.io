---
layout: post
title: squid页面跳转试验
date: 2010-01-27
category: squid
---

某客户页面跳转试验记录

## 一、客户需求

某客户加速域名下某路径http://www.test.com/zhlc/不想让网民直接访问，希望当有直接访问该路径的请求时，都跳转到search.test.com域名下相应的路径去。

## 二、解决思路

a) 客户源站增添rewrite配置进行处理，将该类请求url改写成所期望的url；
b) Squid端对请求进行处理，将该类请求url改写成所期望的url。
根据售前沟通结果，这个处理步骤交由squid完成。

## 三、Squid对request的处理流程（略，见前博文）

## 四、两种跳转方法的介绍与比较

针对跳转需求，提供两个两种方法：
a) Squid支持调用外部程序脚本改写url，即redirect_program（2.6以上版本为url_rewrite_program）。所有的url请求，在squid处理流程的第三步，都会检查rewrite_program，然后将改写后的结果推入流程继续进行（为了提高运行速度，降低服务器负载，可以采用url_rewrite_access控制请求和redirector_bypass在繁忙时进行透传）。
根据《squid中文权威指南》11章的介绍，squid传递给redirect_proram的流格式为：
URL IP/FQDN IDENT METHOD
Rewrite处理时，也就是对这四个字段进行处理，一般地说，也就处理第一个字段——$url。
《squid中文权威指南》中提供了标准的perl脚本，演示了处理办法。我们测试脚本时，只需要创建一个文本文件写出url，对文件执行脚本即可。某客户测试过程如下示，为说明方便，也使用了其他shell命令做比较：
{% highlight bash %}
[root@tinysquid1 etc]# cat testurl.lst
http://www.test.com/zhlc/
http://www.test.com/zhlc/images/1.jpg
http://www.test.com/zhlc/index.html
http://www.test.com/zhlc/index.aspx?oid=1
http://www.test.com/zhlc/index.aspx?oid=1&pid=2
[root@tinysquid1 etc]# cat testurl.lst |sed s/www/search/
http://search.test.com/zhlc/
http://search.test.com/zhlc/images/1.jpg
http://search.test.com/zhlc/index.html
http://search.test.com/zhlc/index.aspx?oid=1
http://search.test.com/zhlc/index.aspx?oid=1&pid=2
[root@tinysquid1 etc]# cat redirector.awk
#!/bin/awk -f
{
    split($1,myarray,".test.com/")
}
{
    myarray[1]=http://search";
    print myarray[1]".test.com/"myarray[2]"\n"
}
[root@tinysquid1 etc]# ./redirector.awk testurl.lst
http://search.test.com/zhlc/
http://search.test.com/zhlc/images/1.jpg
http://search.test.com/zhlc/index.html
http://search.test.com/zhlc/index.aspx?oid=1
http://search.test.com/zhlc/index.aspx?oid=1&pid=2
[root@tinysquid1 etc]# cat redirector.pl
#!/usr/bin/perl -wl
use strict;
$|=1;
while () {
        my ($url,$client,$ident,$method) = ();
        ($url, $client, $ident, $method) = split;
    if ($url =~ m#^http://www.test.com/zhlc/#) {
        $url=~ s/www/search/;
        print "$url\n";
    } else {
        print "$urln";
    }
}
[root@tinysquid1 etc]# ./redirector.pl testurl.lst
http://search.test.com/zhlc/
http://search.test.com/zhlc/images/1.jpg
http://search.test.com/zhlc/index.html
http://search.test.com/zhlc/index.aspx?oid=1
http://search.test.com/zhlc/index.aspx?oid=1&pid=2
{% endhighlight %}
不过虽然awk也是流处理，但作为squid的外挂program测试却没法真起作用。所以只能用perl（网上看到也有用php和python的）。
采用rewrite方法后，squid日志记录如下：
1264603532.881   1147 59.151.*.* TCP_MISS/200 86230 GET http://www.test.com/zhlc/images/header.jpg - DIRECT/1.2.3.173 image/jpeg "http://www.test.com/zhlc/" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; QQPinyinSetup 620; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"
虽然http_status显示的200，不过www.test.com的源站IP为1.2.3.172，search.test.com的源站IP为1.2.3.173，可见squid已经将请求转发给search.test.com了。
由上面的流程可知，squid是先检查acl，然后rewrite，再检查HIT/MISS，所以当设定了search.test.com/.*的cache
deny后，所有www.test.com/zhlc/.*的重复访问也都是MISS。
b) 第二种方法，不属于专门的跳转重定向，算是个妙用吧：
Squid为了美观方便，提供了一些错误信息的定制功能。之前的源站错误跳转，就是修改了ERROR_DIRECTORY里html的meta标签做的。除此以外，针对error_diretory里的ACCESS_DENIED页面，还有专门的另一个configure参数进行定制——deny_info。其用法如下：
{% highlight squid %}
acl test url_regex -i ^http://www.test.com/zhlc/.*
http_access deny test
deny_info http://search.test.com/zhlc/ test
{% endhighlight %}
如果需要显示的信息已经编辑在error_diretory里了，那就可以直接写文件名而不用写url。Squid.conf.default中举例是deny_info
ERR_CUSTOM_ACCESS_DENIED bad_guys。
这个deny_info，常用的地方是防盗链。在deny盗链的同时，加上一个源站的logo图片url，正好让盗链网站替自己做宣传~~
采用deny_info方法后，squid日志记录如下：
1264661272.822 2 59.151.*.* TCP_DENIED/302 320 GET http://www.test.com/zhlc/ - NONE/- text/html "-" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; QQPinyinSetup 620; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"
1264661273.753 854 59.151.*.* TCP_MISS/200 9166 GET http://search.test.com/zhlc/ - DIRECT/1.2.3.173 text/html "-" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; QQPinyinSetup 620; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"
显示的是TCP_DENIED/302。

c) 两个方法比较

最表面可见的不同，就是当IE访问http://www.test.com/zhlc/时，第一种方法地址栏依然显示（httpwatch也一样）http://www.test.com/zhlc/，而第二种方法也显示为http://search.test.com/zhlc/了。
根据之前论述可知，第一种访问时，clinet提出第一个http://www.test.com/zhlc/请求，squid在流程第三步改写url，从search源站取回html代码，查询到相关资源（即http://www.test.com/zhlc/.*），然后重复请求过程，逐一改写，从search源站取回所有文件；
第二种访问时，client提出第一个http://www.test.com/zhlc/请求，squid在流程第二步检查出相匹配的acl规则，返回deny信息给client，即请IE浏览器显示http://search.test.com/zhlc/，然后client重新开始一次链接建立过程，经dns解析等步骤，连上search.test.com的，取回http://search.test.com/zhlc/.*。

## 五、客户页面分析

在日志分析过程中，还发现一个问题，当squid首先从search.test.com源站取回html代码后，为什么调用的相关页面资源url请求也都是www.test.com的呢？看http://www.test.com/zhlc/页面代码，发现如下：
{% highlight html %}
<link href="/zhlc/style/reset.css" rel="stylesheet" type="text/css"/>
<link href="/zhlc/style/main.css" rel="stylesheet" type="text/css"/>
<script src="/zhlc/Scripts/AC_RunActiveContent.js" type="text/javascript">
<a href="#"><img src="/zhlc/images/logo.jpg" width="154" height="80" border="0"/></a>
……
{% endhighlight %}
其页面代码都使用了相对路径，所以才导致了从search端取回的代码依然调用www的url的现象。

## 六、总结

某客户页面跳转试验至此，因为squid处理流程和客户源站代码等多方面原因，只能采用统一跳转至http://search.test.com/zhlc/单一页面的方法，确保客户在IE地址栏里看到有跳转的效果……
最后，总结试验中的两种办法，其改写过程，可以归纳成rewrite是squid-origin过程的，deny_info是squid-client过程的。


