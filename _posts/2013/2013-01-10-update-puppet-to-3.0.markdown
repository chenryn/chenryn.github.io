---
layout: post
title: 升级 Puppet 到 3.0 及其他附件简介
category: devops
tags:
  - puppet
---

今天把 puppet 从2.7 升级到了 3.0。同时放弃了之前通过 ENC 定义所有 top scope variable 的做法，改成只定义一个 role 变量，然后在各个 module 里根据 $role 加载不同的module::role ，把变量都写在 module::role 里。

经历过上次事故后，我对全局变量已经大大的有不安全感，包括 puppet 3.0 新进内核的 hiera ([官网介绍文档](http://docs.puppetlabs.com/puppet/3/reference/lang_classes.html#using-hierainclude)中也说是"like a lightweight ENC")。虽然 module::role 看起来很多是重复内容，还是让人工的操作多经过一些检测才放心。

从 2.7 升级到 3.0 没有太多的不适应。官网上列了很多[不同](http://docs.puppetlabs.com/puppet/3/reference/release_notes.html)。不过实际上基本没改动什么。

* 运行命令统一成 `puppet command` 的形式，2.7的时候还保留的一堆命令都没有了。
* `--apply` 改成 `--catalog`  了。不过这个其实我没用过。
* `pluginsync` 默认开启了。这个是替代 `factsync` 的。2.7 的时候默认还是关闭。给 facter 写插件应该是很容易而且很必要的事情。
* master 内置 webserver 取消了。也就是说原先各种优化文档里的 `--servertype=mongrel` 没用了。但是 3.0 变成了标准 Rack 应用。直接在 `/etc/puppet/rack` 下运行 `rackup -s thin -p 18140 -D -P /tmp/puppetmaster.pid` 就可以了。
* 自然对应的 rack 配置文件 `config.ru` 改了，看 example 就好。
* `include` 可以传递数组
* agent 的 lockfile 把 fork running 和 disabled 区分成两个文件了。不知道能不能消灭掉原先 agent 跑着跑着僵死的情况。

以上是官网列举的主要内容。以下还有我__实际测试中发现的问题__：

* agent 的 puppet.conf 里需要添加一行 `preferred_serialization_format = yaml`，否则默认使用 pson 会直接报错。

----------------------------------------

今天重温了一下 github 在 puppetconf 上的讲演[《chatops》](https://speakerdeck.com/jnewland/chatops)。当然对其中的 hubot 不是重点关注。主要是其中提到的 rodjek 的几个 puppet 相关的项目觉得蛮有用的。

* puppet-lint 

地址：<https://github.com/rodjek/puppet-lint.git>

这是一个语法格式检查器，如果 ERROR 会 `exit 1`。之前两天我还刚在 CPAN 上发现过一个 [Puppet::Tidy](https://metacpan.org/module/Puppet::Tidy) 模块。不过目前为止，这两个都不是很满意：

1. puppet-lint 只能检查格式而不会替你修改格式。
2. puppet-tidy 可以修改格式但是它对格式的检查太简陋了。

当然比 puppet-tidy 稍微好一些的 puppet-lint 也不是很精准，比如他会对所有用双引号定义的变量报 "WARNING: double quoted string containing no variables"；而 puppet-tidy 更奇怪的给我 ip 地址的最后一段再加上了一个单引号变成了下面这个样子：

{% highlight perl %}
    $iplist = ["192.168.1.'2'","192.168.1.'3'"]
{% endhighlight %}

只能说规范化任重道远。

* puppet-profiler

地址：<https://github.com/rodjek/puppet-profiler.git>

这是一个 agent 执行的调试器，不过至今为止功能也还很简单：就是执行一次 

{% highlight bash %}
    puppet agent --test --evaltrace --nocolor
{% endhighlight %}

排序各个 Resource 的执行耗时，并打印前十名。

* rspec-puppet

地址：<https://github.com/rodjek/rspec-puppet>

这是一个 puppet 的 rspec 测试工具扩展。注意他依赖于 `puppetlabs_spec_helper` 但是 gem 里却没写。。。

使用方法看 github 上的说明比较详细了，稍后我再单写一篇介绍。
