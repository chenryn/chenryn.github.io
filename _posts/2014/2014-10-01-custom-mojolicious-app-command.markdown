---
layout: post
theme:
  name: twitter
title: Mojolicious 应用的自定义子命令
category: perl
tags:
  - mojolicious
---

Mojolicious 框架开发应用的时候，可以跟 RoR 一样通过一系列子命令简化很多复杂操作。最简单的来说，就是快速生成整个 web 项目目录：`mojo generate youapp`。更多子命令见：<http://cpan.php-oa.com/perldoc/Mojolicious/Commands>

其实我们还可以自己扩展这个子命令方式，实现自己的子命令。如果打算继续使用 `mojo subcommand` 的方式，那就把自己的子命令模块叫做 `Mojolicious::Command::yourcommand`，而如果打算在自己的名字空间下使用，比如叫 `MyApp::Command::mycommand`，那么需要在 `MyApp.pm` 里加一行代码，设置一下名字空间：

```perl
    sub startup {
        my $self = shift;
        push @{$self->commands->namespaces}, 'MyApp::Command';
        ...
    };
```

然后就可以写自己的 `MyApp::Command::mycommand` 了：

```perl
package MyApp::Command::mycommand;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Command';
use Mojo::UserAgent;

has usage       => "usage: $0 migratint [username] [dashboards...]\n";
has description => "kibana-int index migration for auth users\n";
has ua          => sub { Mojo::UserAgent->new };

sub run {
    my ( $self, $user) = @_;
    my $config = $self->app->config;
    my $ua = $self->ua;
    ...
}

1;
```

大致就是这样：

继承 **Mojolicious::Command** 类。这样就会有 usage 和 description 两个属性和 run 方法。

* usage 属性用来在你执行 `script/myapp help mycommand` 的时候输出信息；
* description 属性用来在你执行 `script/myapp help` 罗列全部可用子命令的时候描述该命令的作用；
* run 方法是命令的入口函数。命令行后面的参数都会传递给 run 方法。如果你的子命令需要复杂处理，这里依然可以用 [GetOpt::Long](https://metacpan.org/pod/Getopt::Long#Parsing-options-from-an-arbitrary-array) 模块中的 `GetOptionsFromArray` 函数处理。
