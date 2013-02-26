---
layout: post
title: awk变量（再续）
date: 2009-11-04
category: bash
tags:
  - awk
---

在squid自动配置脚本里，用到了sed的/r把一个文件的内容插入另一个文件。今天看到awk对两个文件的处理方法，要通过不少运算，不怎么方便。不过作为加深对NR和FNR的不同的理解，还是有些作用。
先说下NR和FNR的不同。
在一次awk中，NR是从头计算到尾的，而FNR是每打开一个文件，就重新计算：
{% highlight bash %}
[root@raocl ~]# awk '{print NR,FNR,$0}' ts st
1 1 123 456
2 2 abc def
3 3 ABC DEF
4 4 654 321
5 1 123 456
6 2 abc def
7 3 ABC DEF
8 4 654 321
{% endhighlight %}
下面转载一个例子：
{% highlight bash %}
[root@raocl ~]# cat a
1000 北京市 地级 北京市 北京市
1100 天津市 地级 天津市 天津市
1210 石家庄市 地级 石家庄市 河北省
1210 晋州市 县级 石家庄市 河北省
1243 滦县 县级 唐山市 河北省
1244 滦南县 县级 唐山市 河北省
[root@raocl ~]# cat b
110000,北京市
120000,天津市
130000,河北省
130131,平山县
130132,元氏县
[root@raocl ~]# awk 'BEGIN{FS="[|,]";OFS=","}NRFNR{print
$1,$2,a[$2]}' a b
110000,北京市,1000
120000,天津市,1100
130000,河北省,
130131,平山县,
130132,元氏县,
{% endhighlight %}

解释：
NRFNR也就是到文件b的时候，打印文件b的第1、2列和之前创建的数组a[北京市]等。


