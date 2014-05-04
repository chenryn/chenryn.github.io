---
layout: post
title: 在 Perl6 脚本中并发执行 ssh 命令
category: perl
tags:
  - perl
  - perl6
  - thread
  - openssh
---

前几天翻 Perl6 模块清单，发现没有用作 SSH 的。虽说 Perl6 里可以很方便的用 NativeCall 包装 C/C++ 库，但是 libssh2 本身就不支持我的 kerberos5 认证环境，所以还是只能通过调用系统命令的方式来完成。

说起来 Perl6 近年一直在宣传 Promise 啊，Supply 啊并发编程，但是 API 变化太快，2013 年中期 jnthn 演讲里演示的 `async` 用法，现在就直接报这个函数不存在了，似乎改成 `start` 了？天知道什么时候又变。所以还是用底层的 Thread 和 Channel 来写。话说其实这还是我第一次写 Thread 呢。

{% highlight perl %}
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
    multi method exec(@hosts, $cmd, $parallel = 5) {
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
{% endhighlight %}

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
* [函数 signature](http://doc.perl6.org/type/Method#signature) 的定义和用法(可选参数那里定义了但是还没用上)
* >> 操作符的用法
  这里其实相当于是 `.finish for @t`。这个怪怪的操作符据说可以在可能的时候自动线程化数组操作，所以返回顺序不会跟`.map`一样。
* xx 操作符的用法
  Perl5 里有 `x` 操作符，Perl6 里又增加了 `xx`、 `X` 和 `Z` 等操作符。分别是[字符扩展成数组](http://doc.perl6.org/language/operators#infix_xx)、[数组扩展成多维数组](http://doc.perl6.org/language/operators#infix_X)和[多数组压缩单个数组](http://doc.perl6.org/language/operators#infix_Z)(也就是zip操作)。
* Channel 和 Thread 对象的用法
  在 roast 测试集里，只有 thread 和 lock 的[测试用例](https://github.com/perl6/roast/blob/master/S17-lowlevel/lock.t)。
  semaphore 其实也支持(因为 MoarVM 是基于 libuv 的嘛，libuv 支持它当然也支持)，但是连测试用例都没写……

默认的并发编程会采用 `ThreadPoolScheduler` 类，稍微看了一下，默认设置的线程数是 16。考虑下一步是仿照该类完善我的小脚本呢，还是重新学习一下 `Supply` 或者 `Promise` 看看到底怎么用。

有兴趣用 libssh2 的童鞋，可以学习一下 [NativeCall](https://github.com/jnthn/zavolaj) 的用法。
