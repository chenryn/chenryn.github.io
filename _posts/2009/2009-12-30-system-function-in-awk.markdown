---
layout: post
title: awk中让人郁闷的system()函数
date: 2009-12-30
category: bash
tags:
  - awk
---

发现一个特尴尬的事实。我辛辛苦苦去百度资料，想用rewrite实现针对不同域名源站故障后的自动跳转功能，但整个思路里遗漏了一个严重的问题。

按我的思路，针对请求的url进行一次curl，然后根据http_code去改写url或者原样输出——这也就意味着，每一个请求，squid都回源去取一次header。那么对于源站来说，前面squid的缓存率，就是0%！完全没有效果。

得重新想过办法……难道去看squid源代码？汗

本着有头有尾善始善终的原则，决定还是把原先那个鸡肋想法写完。根据squid权威指南11章的说法，传递给重定向器的流格式为：URL IP/FQDN IDENT METHOD，其中FQDN和ident经常是空。METHOD，一般是GET和POST，squid只能缓存GET的数据，但不能无视POST方式，因为有时候POST数据header太大的话，squid可能拒绝转发这些内容，这就不好玩了。

在明确这个格式以后（主要是草草收尾的想法影响下），我便觉得其实完全不用perl或者php来搞，简单的awk就足够了——当然，shell不行，因为shell不能从事这种流状的行处理。

以下是本着我想法写的awk脚本：
{% highlight bash %}
#!/bin/awk -f
{
  if(system("curl -o /dev/null -s -w %{http_code}" $1)~/^[2|3]/){
    print ":$1"
  } else {
    print ":http://www.baidu.com/"
  }
}
{% endhighlight %}

但是再度让我郁闷的事情接连发生。

第一，不管我在{}中进行什么操作，程序都把system()的结果print出来了；

第二，即使system()的结果是200，print出来的也是else{}的"http://www.baidu.com"；而如果我直接试验if(200~/^[2|3]/){}else{}，结果就很正常！

试验过程如下：

{% highlight bash %}
[rao@localhost ~]$ echo "http://www.google.com"|awk '{if(200~/^[2|3]/){ print ":"$1 } else{ print ":http://www.baidu.com/"}}'
:http://www.google.com
[rao@localhost ~]$ echo "http://www.google.com"|awk '{if(system("curl -o /dev/null -s -w %{http_code} "$1)~/^[2|3]/){print ":"$1 } else{ print ":http://www.baidu.com/"}}'
200:http://www.baidu.com/
{% endhighlight %}

思前想后，在百度大婶的帮助下，终于搞明白一个问题：system()的结果是直接返回给shell显示了，然后再由awk继续执行后面的程序，这种情况下，if()里留下的其实是system()的执行状态【即0或1】"0"~/^[2|3]/，当然就一直执行else了。

糟糕的问题是awk的getline，无法直接把system()的执行结果导入awk的变量…除非我先system里>一个文件，然后getline<这个文件。MyGod！

而如果采用while("curl"|getline var)的执行方式，如何传递shell变量进去又成了问题……唉

