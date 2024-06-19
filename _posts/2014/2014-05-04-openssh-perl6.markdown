---
layout: post
theme:
  name: twitter
title: 在 Perl6 脚本中并发执行 ssh 命令
category: perl
tags:
  - perl
  - perl6
  - thread
  - openssh
---

前几天翻 Perl6 模块清单，发现没有用作 SSH 的。虽说 Perl6 里可以很方便的用 NativeCall 包装 C/C++ 库，但是 libssh2 本身就不支持我的 kerberos5 认证环境，所以还是只能通过调用系统命令的方式来完成。

Thread 示例
=========================

说起来 Perl6 近年一直在宣传 Promise 啊，Supply 啊并发编程，但是 API 变化太快，2013 年中期 jnthn 演讲里演示的 `async` 用法，现在就直接报这个函数不存在了，似乎改成 `start` 了？天知道什么时候又变。所以还是用底层的 Thread 和 Channel 来写。话说其实这还是我第一次写 Thread 呢。

```perl
use v6;
class OpenSSH {
    has $!user = 'root';
    has $!port = 22;
    has $!ssh  = "ssh -oStrictHostKeyChecking=no -l{$!user} -p{$!port} ";
    multi method exec($host, $cmd) {
        my $out;
        my $shell = $!ssh ~ $host ~ ' ' ~ $cmd;
        try { $out = qqx{ $shell }.chomp }
        CATCH { note("Failed: $!") };
        return $out;
    }
    multi method exec(@hosts, $cmd) {
        my $c = Channel.new;
        my @t = @hosts.map({
            Thread.start({
                my $r = $.exec($_, $cmd);
                $c.send($r);
            })
        });
        @t>>.finish;
        return @hosts.map: { $c.receive };
    }
}

my $ssh = OpenSSH.new(user => 'root');
say $ssh.exec('10.4.1.21', 'uptime');
my @hosts = '10.4.1.21' xx 5;
my @ret = $ssh.exec(@hosts, 'sleep 3;echo $$');
say @ret.perl;
```

很简陋的代码。首先一个是要确认 ssh 不用密码登陆，因为没有写 Expect；其次是没用 ThreadPool，所以并发操作不能太猛，会扭着腰的。

这里演示了几个地方：

* class 的定义和 attr 的定义和[用法](http://doc.perl6.org/language/classtut)
* try-catch 的用法

    也可以不写 try，直接 `CATCH {}` 

* qqx{} 的用法

    这是变动比较大的地方，`qqx` 后面只能用 `{}` 不能用其他字符对了。Perl6 提供另外的 `shell()` 指令，返回 `Proc::Status` 对象。
    不过这个对象其实也就是个状态码，不包括标准输出、错误输出什么的。

* 字符串连接符 ~ 的用法
* multi method 的定义和用法
* [函数 signature](http://doc.perl6.org/type/Method#signature) 的定义和用法，可选参数和命名参数的定义和用法见下一小节。
* `>>` 操作符的用法

    这里其实相当于是 `.finish for @t`。这个怪怪的操作符据说可以在可能的时候自动线程化数组操作，所以返回顺序不会跟`.map`一样。

* xx 操作符的用法

    Perl5 里有 `x` 操作符，Perl6 里又增加了 `xx`、 `X` 和 `Z` 等操作符。
    分别是[字符扩展成数组](http://doc.perl6.org/language/operators#infix_xx)、[数组扩展成多维数组](http://doc.perl6.org/language/operators#infix_X)和[多数组压缩单个数组](http://doc.perl6.org/language/operators#infix_Z)(也就是zip操作)。

* Channel 和 Thread 对象的用法

    在 roast 测试集里，只有 thread 和 lock 的[测试用例](https://github.com/perl6/roast/blob/master/S17-lowlevel/lock.t)。
    semaphore 其实也支持(因为 MoarVM 是基于 libuv 的嘛，libuv 支持它当然也支持)，但是连测试用例都没写……

默认的并发编程会采用 `ThreadPoolScheduler` 类，稍微看了一下，默认设置的线程数是 16。考虑下一步是仿照该类完善我的小脚本呢，还是重新学习一下 `Supply` 或者 `Promise` 看看到底怎么用。

有兴趣用 libssh2 的童鞋，可以学习一下 [NativeCall](https://github.com/jnthn/zavolaj) 的用法。

ThreadPoolScheduler 示例
===========================

根据 [S17-concurrency 文档](https://github.com/perl6/specs/blob/master/S17-concurrency.pod) 的内容，改写了几行脚本，实现了 ThreadPool 的效果：

```perl
    multi method exec(@hosts, $cmd, :$parallel = 16) {
        my $c = Channel.new;
        my $s = ThreadPoolScheduler.new(max_threads => $parallel);
        @hosts.map({
            $s.cue({
                my $r = $.exec($_, $cmd);
                $c.send($r);
            })
        });
        return @hosts.map: { $c.receive };
    }
```

这里把默认并发值改成了 16，跟 Rakudo 保持一致。如果不需要可调的话，这里其实可以直接写成 `$*SCHEDULER.cue({})`。

然后调用方法也对应修改一下，考虑到辨识度，把并发值改成了命名参数。调用方法如下：

```perl
my @hosts = slurp('iplist.txt').lines;
my @ret = $ssh.exec(@hosts, 'sleep 3;echo $$', :parallel(5));
```

运行可以看到，虽然 iplist.txt 里放了 40 个ip，但是并发的 ssh 只有 5 个。

Promise 示例
==========================

继续，S17 内容下一节是 Promise，之前博客里已经提过几次 Perl5 的 [Promises 模块](https://metacpan.org/pod/Promises) 或者类似的东西(比如 [Mojo::IOLoop::Delay](/2014/01/22/explain-mojo-ioloop-delay-testing) )，包括 JavaScript 等也有一样的名字。

不过 Perl5 的 Promises 思路参照的是 Scala，语法则偏向 nodejs 和 golang(都用一个叫 `defer` 的指令来创建 Promises 对象)，写起来跟 Perl6 的原生 Promise 差距较大。

考虑 ssh 这个场景可能不太用的上 Promise 的 `.in`、`.then`、`.anyof` 之类的流程控制(尤其 `.in` 这个还不一定能用，因为 Promise 底层也是用的 `$*SCHEDULER.cue()`，而这个在 MoarVM 上目前还不支持 :in/:at/:every 等参数)，就直接展示最简单的并发了：

```perl
    multi method exec(@hosts, $cmd, :$parallel = 16) {
        $*SCHEDULER = ThreadPoolScheduler.new(max_threads => $parallel);
        await @hosts.map: {
            start {
                $.exec($_, $cmd);
            };
        };
    }
```

简单来说，就是每个 `start {&c}` 创建一个 Promise 对象，根据 &c 的返回值自动作 `$p.keep($result)` 或  `$p.break(Exception)`。然后 `await(*@p)` 回收全部 Promise 的结果。

这里直接修改了 `$*SCHEDULER` ，这是一个全局变量，即当前进程的调度方式。Promise 类默认就采用这个变量。如果想跟上一小节一样使用 `$s`，那这里就不能用 `start {}` 而是要用 `Promise.start({}, $s)`。显然写起来不怎么漂亮。

Supply 示例
========================

Supply 是响应式编程，类似 Java 里的 Reactive 概念。应该适合的是一件事情多个进程重复做。场景不太对，二来目前 S17 也不全，就不写了。

