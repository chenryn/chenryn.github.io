---
layout: post
title: apache的rewrite伪静态化问题一例
date: 2011-02-16
category: apache
---

某应用系统有一个产品翻页浏览，为了利于搜索引擎，准备把/search.html?param=1-2-3-4-5做伪静态化，变成/search/1-2-3-4-5.html的url显示。

想来很简单，确认apache有mod_rewrite后，加入如下配置，重启即可：
{% highlight apache %}
<IfModule mod_rewrite.c>
RewriteEngine on
RewriteCond %{HTTP_HOST} ^example\.domain\.com [NC]
RewriteCond %{REQUEST_URI} ^/search/.*\.html
RewriteRule ^/search/(.*)\.html /search.html?param=$1 [P,L]
</IfModule>{% endhighlight %}
不过很不幸的事情出现了：不管点击页面搜索结果的哪个页码，看到的永远都是第一页的内容！！

是搜索程序有问题么？试着直接访问/search.html?param=1-2-3-4-6，能看到之后某页的新内容。

于是打开apache的rewritelog看看究竟：
{% highlight apache %}RewriteLog /www/admin.game.china.com/logs/rewrite.log
RewriteLogLevel 9{% endhighlight %}
在rewrite.log中看到如下记录：
{% highlight apache %}[rid#13c4e40/initial] (2) init rewrite engine with requested uri /search/0-0-0-0-0-0-0-0-0-2.html
[rid#13c4e40/initial] (3) applying pattern '^/search/(.*)\.html' to uri '/search/0-0-0-0-0-0-0-0-0-2.html'
[rid#13c4e40/initial] (4) RewriteCond: input='example.domain.com' pattern='^example\.domain\.com' => matched
[rid#13c4e40/initial] (4) RewriteCond: input='/search/0-0-0-0-0-0-0-0-0-2.html' pattern='^/search/.*\.html' => matched
[rid#13c4e40/initial] (2) rewrite /search/0-0-0-0-0-0-0-0-0-2.html -> /search.html?param|0-0-0-0-0-0-0-0-0-2
[rid#13c4e40/initial] (3) split uri=/search.html?param|0-0-0-0-0-0-0-0-0-2 -> uri=/search.html, args=param|0-0-0-0-0-0-0-0-0-2
[rid#13c4e40/initial] (2) local path result: /search.html
[rid#13c4e40/initial] (2) prefixed with document_root to /www/example.domain.com/search.html
[rid#13c4e40/initial] (1) go-ahead with /www/example.domain.com/search.html [OK]{% endhighlight %}
看起来似乎没有问题……

为了更细致一点，在测试环境中用单进程方式启动apache，通过strace来跟踪httpd。更明确看到了rewrite之后的内部请求"GET /search.html?param=0-0-0..."完全没有问题。

于是找开发同事商量，询问这个\.html?param=是如何完成翻页功能的。结果得知是html中有javascript，翻页就是通过js来完成的。

恍然大悟！js是在浏览器端完成解析工作的，那么在apache里rewrite的时候传输过去的args没有起到作用，服务器返回的永远是默认的html内容，即第一页内容。同事修改程序，将翻页方式改成另外的jsp来完成，我再修改rewrite规则到jsp上。一切OK了！
