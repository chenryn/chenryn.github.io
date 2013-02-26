---
layout: post
title: 用Spork和Template::Toolkit生成slides胶片展示
date: 2012-06-01
category: perl
---

在不少技术集会上，大家都不再采用ppt而是使用pdf，甚至浏览器，编辑器来显示内容。利用js和css完成slide效果已经越来越花哨。另一个用vim的流派也让人很是惊叹~    
那不会css的童鞋怎么办呢？这里有个笨办法。用Spork工具生成html页——反正slide一般内容不多，html代码重复一点也不浪费啥事儿~用template技术刚刚好。
Spork是一个在Sporx基础上构成的工具，可以直接cpan安装，不过默认情况下没有plugin。所以比较好的办法是上git找个带plugin的代码clone。这样页面样式好看点。    
比方我用的这个就是Spork作者用的：[Spork-pm](https://github.com/ingydotnet/spork-pm)

新建一个slide的工程相当简单：
{% highlight bash %}
git clone https://github.com/ingydotnet/spork-pm.git
cd spork-pm
perl Makefile.PL
make && make install
# 必须新建，非空目录时命令无效
mkdir /tmp/slides
cd /tmp/slides
Spork -new
Spork -make
Spork -start
{% endhighlight %}

在slide里每张都加载,css和js都是重复的。make的过程就是使用template展开的问题。start就是打开浏览器的命令行的alias。这里其实可以优化一下改成外链css/js(默认是因为有些控制bgcolor啊之类的spork语法可以在单页里用，所以就没外链)~    
注意template里的模板html里charset都是写的UTF-8编码，而在win上，编辑器默认是GB2312的，需要更改过来。

具体语法，----表示一页；==表示大标题；*表示小条目，*越多条目等级越低；+表示稍后显示(其实就是在本页基础上再开新页)。    
然后还有一些config定义，用来显示head，foot和start页内容的。    

最后，上一个最近我的slide，关于DNS协议和应用的内容，浏览地址见：
[DNS协议与应用](http://chenlinux.com/dns-slides/slides/start.html)

比较无语的是js控制翻页这块。我的笔记本键盘只能捕获中间正常键位信号，上下左右、home、end、pgon、pgdn这些统统不行。无奈只好改用输入法一样的逗号,句号.翻页了……
