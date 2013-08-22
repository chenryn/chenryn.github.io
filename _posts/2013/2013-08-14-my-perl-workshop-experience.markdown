---
layout: post
title: BeiJing Perl Workshop 2013 参会总结
category: perl
---

上周六在万通会议中心参加了 BeiJing Perl Workshop 2013 ，并做了 40 分钟长的关于 ElasticSearch 的演讲。上届 2011 作为一个看客，两年后作为一个积极参与和演讲者，真的有必要记录一下。

一天中最让大家惊奇和感兴趣的无疑是胡松涛带来的 3D 打印机以及每人都有的 Perl 小挂件 —— 没错，就是用 3D 打印出来的小东西。

![large](/images/uploads/3d_perlchina.jpg)

![small](/images/uploads/3d_perl.jpg)

最遗憾的是来自alibaba的两位演讲者因为公司问题临时退出。

DeNA 的演讲者是一位由程序员转职的产品经理，明显演讲的技巧水平是要高过我们这些纯码农的，节奏控制完全值得学习。
不知道对于其他 perler 来说，测试是否会主动去做，但是我是蛮习惯使用 `Dancer::Test` 的，包括其他项目用 `Test::More`，我觉得都是蛮好的习惯。所以对董余康在演讲中比较重点的提到测试的便捷我是比较有爱的，但是从 QQ 群上的反应来看，大家更期待的功能和开发便捷上的介绍？
总的来说，演讲题目偏于 PerlDancer 的 hello world，我个人本身对 Dancer 有一定了解，所以内容上没太注意。如果以后发现大家对 `Dancer` 有进一步的兴趣，我考虑可以在 YY 频道上介绍一下用 `Dancer::Plugin` 实现一个自己喜欢的keyword？

扶凯的 `Mojolicious` 演讲应该就比较符合大众的期待。我是不太喜欢单独定义 route 的方式，不管是 RoR 还是 mojo，除此以外，mojo 另一个不错的就是 `TagHelper` 了。我觉得将 `Dancer` 和 `Mojolicious::Lite` 相比是不厚道的，`Dancer` 也可以多文件使用，`dancer -a web_app` 命令就生成了完整的项目层次。
关于 mojo 的演讲，牛氓同学说没有关于 `Mojo` 的 OO 实现的内容，我也觉得比较遗憾，不过这个内容是否适合在面对上百听众的时候分享，也是一个问题？

李瑞彬演讲中提到的 `cpanspec` 和 `yum search perl(LWP::Simple)` 两个小技巧很不错～

刘刊和大家不同，采用了直接 code 解读和 shell 演示的办法介绍了他的 `pantheon` 里面的一些思想和简单用法。其实我去年就见过这个的使用，不过似乎到现在依然没有完整的文档？作为一个在雅虎超大环境下经过实践的自动化运维平台项目，如果配上完善的文档，应该可以成为一个可以对 Perl 普及有很不错推动力的好项目。__真心希望刘刊和 `pantheon` 的其他使用者可以花点时间，整理一份快速入手的 cookbook，迁移代码到github，独立域名发布，完成从内部项目到社区项目的转身～__
目前只能通过 CPAN 安装，安装很方便，但是没人演示教导，真的不知道怎么用……

也来说说我自己的演讲。这个话题其实比较尴尬，前三分之一介绍 `ElasticSearch`，中间还有一部分是 `logstash`，都是 Perl 无关的内容。演讲完后其实发现很多人依然不清楚到底是可以用来干吗……或许我直接只讲 `Message::Passing` ，每个插件如何用，效果应该更好一些吧？唯一高兴的，是演讲刚好控制到了40分钟内讲完。

许大师提到一个大计划，要把 `AnyEvent` 和 `nginx` 无缝结合。这个好是好，能不能出来是另一回事……

闪电演讲依然火爆，不过我有事情先走了，不知道后来还有几位超时被敲锣的～～
对了，第一个闪电提到的 `$obj->can($func_name)->()` 这个用法很帅，记录一下。

原本在 CU 上答应网友在闪电上分享一下 `autobox` 的用法，也没法做了，有点违约的小羞愧。以后也争取在 YY 频道上说说。

作为演讲者，还另外免费领了一本《HBase管理指南》，实在其他几本 Perl 的都已经有了——而且大多数演讲者都是～～

BJPW 之后第二天就开始 YAPC::EU，国外大神基本都在欧洲讨论 Future Perl，北京的朋友们自娱自乐也还是比较成功了～

最后吐槽一个，全天没有 Perl6 的演讲，结果文化衫上是 Perl6 的蝴蝶。。。其实如果能让广州那个 `MoarVM` 的开发者叫来讲讲也挺好的。

附另外两位同仁的大会感受博文：

1. [@赵涛Alick](http://www.weibo.com/alickzhao) 的 《[Perl China 2013 活动后记](http://wp-awesome.rhcloud.com/2013/08/18/perl-china-2013-notes/)》
2. Aka.Why 的 《[参加Beijing Perl Workshop 2013后感](http://blog.aka-cool.net/blog/2013/08/12/learn-from-beijing-perl-workshop-2013/)》
