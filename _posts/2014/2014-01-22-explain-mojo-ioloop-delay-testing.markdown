---
layout: post
title: Mojo::IOLoop::Delay 模块测试代码解释
category: perl
---

昨天有人在群里问起[Mojolicious/t/mojo/delay.t](https://metacpan.org/source/SRI/Mojolicious-4.68/t/mojo/delay.t) 中一段代码的执行原理。代码如下：

```perl
use Mojo::Base -strict;
 
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}
 
use Test::More;
use Mojo::IOLoop;
use Mojo::IOLoop::Delay;
 
my $delay = Mojo::IOLoop::Delay->new;
my $finished;
my $result = undef;

$delay->on(finish => sub { $finished++ });
$delay->steps(
  sub {
    my $delay = shift;
    my $end   = $delay->begin;
    $delay->begin->(3, 2, 1);
    Mojo::IOLoop->timer(0 => sub { $end->(1, 2, 3) });
  },
  sub {
    my ($delay, @numbers) = @_;
    my $end = $delay->begin;
    Mojo::IOLoop->timer(0 => sub { $end->(undef, @numbers, 4) });
  },
  sub {
    my ($delay, @numbers) = @_;
    $result = \@numbers;
  }
);

is_deeply [$delay->wait], [2, 3, 2, 1, 4], 'right return values';
is $finished, 1, 'finish event has been emitted once';
is_deeply $result, [2, 3, 2, 1, 4], 'right results';
done_testing();
```

首先介绍一下这个 `Mojo::IOLoop::Delay` 模块，这是异步编程中很火很实用的一个概念，一般叫 `Promise` / `Deferred` 。你可以按照顺序编程的思路组合那些异步函数，比如在这个例子里主要就体现了 `steps` 方法和 `finish` 事件。

`steps` 方法中可以传递任意多个异步函数。第一个函数立刻执行，然后等 `$delay` 信号量(由 `begin` 方法控制)释放(即重新等于0)后逐次执行后面的函数，直到碰到一个不调用 `begin` 控制信号量的函数，或者触发 `error` 或者 `finish` 事件。

`begin` 方法返回的回调函数 `$end->()` 用来减信号量。如果传递了参数给这个回调函数，那么第一个参数会被忽略，剩下的参数会 `push` 进下一个顺序或者事件触发函数的参数列表里，同时推送到 `wait` 方法。

所以上面这段测试的数据执行结果是这样的：

1. `$delay->wait` 开始整个 `ioloop`, `steps` 方法首先执行 sub1 ，首先通过 `$delay->begin()`给信号量加1；
2. 随即触发 `timer` 事件，`$end->(1, 2, 3)` 将 `(2, 3)` 推入下一个函数 sub2 的 `@_` 里，同时把信号量减1；
3. 信号量变成0，继续执行，这一行 `$delay->begin()->(3, 2, 1)`，将 `(2, 1)` 推入下一个函数 sub2 的 `@_` 里，注意这里信号量实际也加减过一次，只是这里的回调函数直接匿名调用了；
4. sub1 执行完成，信号量为0，那么开始下一个sub2，sub2 传入的参数列表其实是 `($delay, (2, 3), (2, 1))`，也就是说这时候的 `@numbers` 是 `(2, 3, 2, 1)`；
5. sub2 执行流程类似 sub1 ，信号量加1，触发 `timer` 事件，然后 `$end->(undef, @numbers, 4)` 把 `((2, 3, 2, 1), 4)` 推入下一个函数 sub3 的 `@_` 里，同时信号量减1；
6. sub2 执行完成，信号量为0，那么开始下一个sub3，sub3 传入的参数列表就是 `($delay, (2, 3, 2, 1, 4))`，也就是说这时候的 `@numbers` 是 `(2, 3, 2, 1, 4)`；
7. sub3 将 `@numbers` 的引用赋值给 `$result`，因为 sub3 里没有对信号量的操作，而且也是最后一个了，`steps` 完成，触发 `finish` 事件；
8. 注册的 `finish` 事件回调函数把 `$finish` 变量加1；
9. `$delay->wait` 这时候也收集完毕前面每个 `$end->()` 的参数列表，和每步 `@numbers` 是同步的，同时因为 `finish` 事件被触发，就此停止 `ioloop`，程序完成，返回整个列表。

如上。
