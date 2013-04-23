---
layout: post
title: 给自己写个运维语言(Newbie::Gift 介绍)
category: perl
---

[Achilles Xu](http://weibo.com/formalin14) 提出了一个 [Newbie::Gift](https://github.com/PerlChina/Newbie-Gift) 计划，希望可以导出 100 个常用函数，解决 90% 的新手上手问题。不过最近他想的更远，先着手去写 [perl-lisp](https://github.com/formalin14/perl-lisp) 项目了，打算把 perl 的语法更加的偏离原样，变成 lisp-like 的样子。

所以在他完成整个工作之前，我打算先给自己实现一小部分常用函数，解决个人工作中的问题。维持 SPEC 中提出的尽量使用回调风格的做法，但是就不用自定义的 `def_class` 来实现类了，而且尽量把东西做成 CPAN-like 的模块，所以把主要模块都放在 NG/ 下了。

我的 fork 地址是： <https://github.com/chenryn/Newbie-Gift>。

目前实现的函数主要有：

* local_run

封装了 `IPC::Open3` 模块，回调传递 STDOUT 和 STDERR。

* web_get

封装了 `AnyEvent::HTTP` 模块，实现了 SPEC 中提到的自动并发下载和回调传递 header 和 body。这里学习 `Mojo` 的做法，返回的 body 可以用 `->find()`，`->each`，`->text`，`->attr('')` 来取具体的值。

不过这里只从 `Web::Query` 模块扒(主要就是把原来的@array数组操作都修改成了自定义的Array对象操作)过来了获取的方法，修改的方法都放弃了。感觉没啥必要。

* mail_get

封装了 `Net::POP3` 模块，因为这个模块是核心库的，不需要安装太多依赖。倒序回调传递每封邮件 `Hashtable` 类的 header 和 `Array` 类的 body。其中body的第一个元素是 `HTTP::DOM` 对象。

* read_file

实现 SPEC 描述的回调。

* read_dir

回调中使用 `File::Find` 来递归读取目录下的文件，类似 `find` 的作用；直接返回值的话则是第一层次的文件，类似 `ls` 的作用。

* process_log

实现 SPEC 描述的回调。不过自动兼容空格和引号没想好怎么做比较恰当，暂时是默认空格，用其他分割就在回调后面再提供一个参数。

* db

实现回调处理 CRUD 的返回值。想法本来是来自 `Dancer::Plugin::Util::Handle` 的 `quick_select`/`quick_insert`/`quick_update`/`quick_delete`，不过目前没有选择自己拼接 SQL，而是使用 SQL::Abstract 模块。

* file_stat

stat 是 perl 默认的函数，不过返回的数组在 mode 和 time 方面可读性都不好，所以封装一下，提供更加可读的 0644 这样的 mode 格式；time也返回自定义的 Time 对象方便使用。

此外还有 `from_yaml`/`from_json`/`mkdir_p`/`rm_p`/`mail_send` 等等小函数。__`web_server` 这个没想好具体目的，是要像 `AnyEvent::HTTPD` 那样返回字符串的，还是 `Plack::App::Directory` 那样发布本地目录的呢？`remote_run` 这个预备还是在 `Net::OpenSSH` 上做，同样也要自动并发。__

在基类基础上也实现了两个类：

* HTTP::DOM

* Time

最终在 NG.pm 中导出全部函数，这样只需要 `use NG;`一行就可以全部使用了。

顺带还 import 了 `warnings`，`strict` 和 5.010 的 `features`。这里写法如下：

{% highlight perl %}
    sub import {
        my $class = shift;
        strict->import;
        warnings->import;
        utf8->import;
        feature->import(':5.10');
        $class->export_to_level(1, $class, @EXPORT);
    }
{% endhighlight %}

`import` 和 `export_to_level` 都是 `Exporter` 模块的方法，`NG.pm` 里继承了 `Exporter`。
