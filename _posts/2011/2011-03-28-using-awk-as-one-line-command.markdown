---
layout: post
title: awk单行命令
date: 2011-03-28
category: bash
tags:
  - awk
---

一眨眼又几天没更新，中午在Q群里聊到一个单行命令，随手记录下。
A需求：某文件如下
aaa
bbb
aaa
aaa
ccc
aaa
ddd
……
通过命令改成如下格式：
1
bbb
3
5
ccc
7
ddd
……
方法如下：
{% highlight bash %}
echo -en 'aaa\nbbb\naaa\naaa\ndddd'|awk 'BEGIN{tag=1}{if(/aaa/){print tag;tag+=2}else{print}}'{% endhighlight %}
或者更短一点：
{% highlight bash %}
echo -en 'aaa\nbbb\naaa\naaa\ndddd'|awk 'BEGIN{tag=1}{if(/aaa/){$0=tag;tag+=2};print}'{% endhighlight %}
B需求：
aaa不是文件一行的全部内容，而只是一部分。
方法如下：
{% highlight bash %}
echo -en 'aaa\nbbb\naaa\nfdaaafdaaa\ndddd'|awk 'BEGIN{tag=1}{gsub(/aaa/,tag) && tag+=2;print}'{% endhighlight %}
以上三种，凯的perl版本分别如下：
{% highlight perl %}
perl -nale 'BEGIN{$tag = 1}if(/aaa/){print $tag;$tag+=2}else{print}'
perl -nalpe 'BEGIN{$tag = 1};$_=$tag and $tag+=2 if /aaa/'
perl -nalpe 'BEGIN{$tag = 1};$tag+=2 if s/aaa/$tag/'{% endhighlight %}
