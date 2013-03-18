---
layout: post
title: resin-status
date: 2011-01-12
category: monitor
tags:
  - resin
---

和apache、nginx一样，resin也自带了一个比较简易的status模块，只需要在resin.conf里配置就行了。在里添加如下一段：

{% highlight xml %}
    <servlet-mapping servlet-class='com.caucho.servlets.ResinStatusServlet'>
      <url-pattern>/resin-status</url-pattern>
      <init enable="read"/>
    </servlet-mapping>
{% endhighlight %}

重启resin即可。

然后curl访问http://127.0.0.1:8080/resin-status就可以看到输出了。

用浏览器的话，大致如下图：
![resin](/images/uploads/resin.jpg)

可以关注线程数、连接数、内存使用大小和请求处理数。

如果要做监控的话，直接从html里获取相应数值即可。

唯一需要稍微注意的是请求处理数。因为其他的都是AVERAGE，只有这个是COUNTER型的。要是想很方便的看到rps。可以采用如下方法查看：

{% highlight bash %}
# a=`curl -s http://127.0.0.1:8081/resin-status|awk -F/ '/Invocation/{print $NF}'`;sleep 1;curl -s http://10.168.168.56:8081/resin-status|awk -F/ '/Invocation/{print($NF-'$a'}'
718
{% endhighlight %}

这里比较有趣的是因为这行的数据本身是有个括号的，所以就有了各种各样的写法和报错了。一并贴上来，可以体会一下awk的系统变量/内部函数/字符类型的用法：

{% highlight bash %}
# a=`curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF}'`;sleep 10;curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF-'$a'}'
awk: cmd. line:1: /Invocation/{print $NF-3949612)}
awk: cmd. line:1:                               ^ syntax error
# a=`curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF}'`;sleep 10;curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF-'"$a"'}'
awk: cmd. line:1: /Invocation/{print $NF-4025373)}
awk: cmd. line:1:                               ^ syntax error
# a=`curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF}'`;sleep 10;curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF-"'$a'"}'
7607
# a=`curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print substr($NF,0,length($NF)-1)}'`;sleep 10;curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF-'$a'}'
7927
# a=`curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print $NF}'`;sleep 10;curl -s http://127.0.0.1:8080/resin-status|awk -F/ '/Invocation/{print($NF-'$a'}'
7212
{% endhighlight %}
