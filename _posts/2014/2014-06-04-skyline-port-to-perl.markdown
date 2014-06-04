---
layout: post
title: 用 Perl5 改写 skyline 异常检测算法
category: monitor
tags:
  - python
  - numpy
  - PDL
  - perl
  - skyline
---

一直以来都知道 Perl5 里也有类似 numpy 的库叫 PDL，但是因为上手资料比较少，官网文档比较烂，就没认真看过。这次因为要了解 skyline 里用到的 9 种异常检测算法的具体原理，正好一一对照重写一下，当做是学习 PDL 了。

最终修改完的 Perl5 版如下：

<script src="https://gist.github.com/chenryn/43315b6c7ddaf9c39aab.js"></script>

要承认 PDL 在上手方面比不过 numpy，比如取数组长度，PDL 里居然写作 `$p->nelem`；取数组最后一个元素的值，更是要写作 `$p->index($p->nelem - 1)` 这么长！相比在 numpy 方面几乎看起来还是跟操作原生的 python 类型一样。。妈蛋 PDL 你多重载几个操作符会死啊！

稍微复杂一点的多维操作 PDL 还是很方便的。比如程序里 `least_squares` 检验法的时候，numpy 有这么一句：

{% highlight python %}
    A = np.vstack([x, np.ones(len(x))]).T
{% endhighlight %}

而在 PDL 里可以写作：

{% highlight python %}
    my $A = $x->dummy(0)->append(1);
{% endhighlight %}

PDL 里也有 ones() 函数来生成全部由 1 构成的数组，不过我觉得上面这个写法明显更好理解最终目的，就是90°倒转数组然后每个元素作为子数组后面加第二个元素嘛。

*当然，比较好玩的是最后我发现 `least_squares` 在 PDL 里可以直接搞出来结果，不用这么复杂*

比较基础的数值统计还是比较好搞的，麻烦的是一些现成的正态分布检验法。python 版里使用的是 [K-S 检验法](http://en.wikipedia.org/wiki/Kolmogorov-Smirnov_test)——其实只是命名，里面实际还用了 [A-D 检验法](http://en.wikipedia.org/wiki/Anderson%E2%80%93Darling_test)做改进——我还记得这是 skyline 开源以后社区人帮忙实现的，Etsy 一开始都没有。按说 K-S 检验法是非常基础的一个，但是我找遍了 CPAN 确实就没有(大概是因为 Perl 里调用 R 太方便了，大家都习惯直接用 [Statistics::R](https:://metacpan.org/pod/Statistics::R) 模块吧)。于是最后这个改成 [S-W 检验法](http://en.wikipedia.org/wiki/Shapiro%E2%80%93Wilk_test)。

**根据 SPSS 的规范，一般在数值序列长度小于 5000 的时候，S-W 检验法可信度高于 K-S 检验法；大于 5000 的时候，K-S 检验法可信度大于 S-W 检验法。**

考虑这里一般只会检查最近一个小时的数据。一个小时内就算一秒钟一次也就是 3600 个点。事实上应该至少是 10 秒钟出一个统计值才会做比较。那么也就是几百个点，用 S-W 检验法应该更有效。

在重写这个脚本的时候，找到了很多关于这方面的资料，下面这两个链接应该是非常不错:

1. <http://www.itl.nist.gov/div898/handbook/index.htm>
2. <http://www.perlmonks.org/?node=Stats%3A%20Testing%20whether%20data%20is%20normally%20(Gaussian)%20distributed>

此外，脚本中本身用到的 [ta-lib](http://www.ta-lib.org) 和 [Statistics::Distributions](https:://metacpan.org/pod/Statistics::Distributions) 模块也还有更多的算法函数提供，值得留意。

注：PDL::Finance::Talib 模块必须先自己编译了 ta-lib 依赖后才能安装。之前测试在美团云主机上做的，结果还安装失败。后来发现是内存不够大==!然后在作者的指导下学会一招，在内存不够大的机器上，可以删除掉 CCFLAGS 里的 `-pipe` 参数，也能正常编译通过。
