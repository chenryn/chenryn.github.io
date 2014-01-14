---
layout: post
title: 利用 staticperl 和 upx 生成 单个可执行 perl
catagory: perl
---

Perl 程序打包的问题由来已久。

最早是 perlcc，但是从5.10版本以后，B::CC 等一系列模块跟不上开发脚本导致 perlcc 也无法使用。

然后是PAR::Packer，唐凤大神的作品。

今天介绍另一个模块，App::Staticperl，同样是大神级作品，作者是Marc Lehmann。他的 AnyEvent、Coro、EV 无不大名鼎鼎。而staticperl，就是他开发出来用以方便自己部署程序的。

staticperl 官网上有一句很霸气的描述：“perl, libc, 100 modules, all in one standalone 500kb file”。

不过经我测试，按照官网上的步骤是做不出来这么小的单文件的！幸运的是我在 Perlmonks 上的[发问](http://www.perlmonks.org/?node_id=1065912)很快收到了答案，这个还要用上另一个工具：upx。

测试过程如下：

{% highlight bash %}
# cpanm App::Staticperl
# staticperl install
# staticperl instcpan AnyEvent AnyEvent::HTTP
# staticperl mkperl -MAnyEvent -MAnyEvent::HTTP
# staticperl mkapp myapp --boot myapp.pl -MAnyEvent -MAnyEvent::HTTP
{% endhighlight %}

而如果是官网说的 [smallperl](http://staticperl.schmorp.de/smallperl.html)，则是采用 `mkbundle` 的方法。

除了使用单独的[配置文件](http://staticperl.schmorp.de/smallperl.bundle)存放太长的参数，其他和 `mkapp` / `mkperl` 一致。

不过运行结果是：生成的单个文件有3.5MB大小。

然后使用 upx：

{% highlight bash %}
# apt-get install upx
# upx --best smallperl.bin
{% endhighlight %}

就得到压缩后的超小型perl了。这个perl内含了AE、Socket、common::sense、List::Util 等一系列常用模块可以直接使用。不过大小依然有 1.7MB 。看来是 Perl5.14 本身大小也变大了。

__补充__

按照评论里的建议，改用 `--lzma` 选项再压缩一次：

{% highlight bash %}
# upx -d smallperl.bin
# upx --lzma smallperl.bin
{% endhighlight %}

结果到 1.4MB 大小。
