---
layout: post
title: Future模块和AnyEvent事件驱动的结合
category: perl
tags:
  - anyevent
  - future
---

上个月的 advent calendar 活动中，有一个新的模块进入我们视野，这就是 IO::Async 模块作者写的 [Future](https://metacpan.org/pod/Future) 模块。通过 Future 模块，我们可以做到对异步请求的各种控制，比如：

* `needs_all` / `needs_any` / `wait_any` / `wait_all`
* `then` / `else` / `and_then` / `or_else` / `followed_by`
* `on_ready` / `on_done` / `on_fail` / `on_cancel`

目前来说，IO::Async 是原生支持 Future 了的。但是 AnyEvent 框架才是目前 Perl 社区事件驱动编程的主流选择。还好 Future 源码目录下 [examples/](https://metacpan.org/source/PEVANS/Future-0.21/examples) 里有关于 AnyEvent 和 POE 如何跟 Future 一起运行的示例。

示例统一举例的是 timer 事件。而我更看好的是 [Future::Utils](https://metacpan.org/pod/Future::Utils) 提供的一些关于循环的函数，比如 `fmap` 可以很简单的控制住异步的并发数。稍微试验，得到脚本如下：

```perl
package Future::AnyEvent;
use base qw( Future );
use AnyEvent;
use AnyEvent::HTTP; 
sub await {
   my $self = shift;
   my $cv = AnyEvent->condvar;
   $self->on_ready(sub { $cv->send });
   $cv->recv;
}
sub httpget {
   my $self = shift->new;
   http_get(shift, sub {
      my ($content, $headers) = @_;
      $self->done($content);
   });
   return $self;
}
 
package main;
use Future::Utils qw/fmap/;
my @urls = qw(
    http://www.sina.com.cn
    http://www.baidu.com
    http://www.sohu.com
#    ...
);
my $f = fmap {
    Future::AnyEvent->httpget( shift );
} foreach => \@urls, concurrent => 5;
my @res = $f->get;
print @res;
```

看起来稍显复杂。这里其实最关键的就是几个接口函数：

* await / on_ready

Future 对象到实际执行时(即->get调用处)，会寻找 `await` 方法。所以必须给自己选用的事件驱动实现这个 `await` 方法。

ready 状态即一个 Future 执行完成，注意执行完成不意味着执行成功，ready 状态包括 success 和 fail 两种，其实是可以分别定义 `on_success` 和 `on_failure` 回调的。
`on_ready` 回调的作用是：在该 Future 对象达到 ready 状态的时候，执行这步调用。

在本例使用 AnyEvent 的时候，也就是一般来说都会在每步操作结束的 `$cv->send` 改到这里来等待调用。

* done / done_cb

那 Future 对象的 ready 状态是怎么来的呢？就是这步了：`$f->done` 一旦被调用，就意味着该 Future 对象进入了 ready and success 状态。

同样，如果你要详细控制 Future 对象进入具体的 ready but failure 状态，就使用 `$f->fail` 好了。

调用 `->done|fail()` 的时候，你可以选择传递具体哪些数据。比如本例中，就只传递了抓取的 `$content` 而没有 `$headers`。

Future 提供了 `->done_cb` 和 `->fail_cb` 两个回调函数，默认传递回当前全部数据。本例如果要传回全部，就可以直接写成`http_get shift, $self->done_cb`。

好了，就到这里。这个例子虽然比 Future 自带的 `anyevent.pl` 示例稍微复杂一点，但是依然很简单。如果能引起大家的兴趣，请直接阅读官方文档。
