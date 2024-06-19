---
layout: post
theme:
  name: twitter
title: Rex::Test::Spec 模块
category: perl
tags:
  - devops
  - serverspec
  - rex
  - testing
---

上篇说了 serverspec 工具，我一直对 Rspec 的语法蛮有好感的，于是昨晚花了点时间模仿这个给 Rex 写了个类似的工具，叫 Rex::Test::Spec，源代码地址见：<https://github.com/chenryn/Rex--Test--Spec>。

语法大概是这样的：

```perl
    use Rex::Test::Spec;
    describe "Nginx Test", sub {
        context run("nginx -t"), "nginx.conf testing", sub {
            like its('stdout'), qr/ok/;
        };
        context file("~/.ssh/id_rsa"), sub {
            is its('ensure'), 'file';
            is its('mode'), '0600';
            like its('content'), qr/name\@email\.com/;
        };
        context file("/data"), sub {
            is its('ensure'), 'directory';
            is its('owner'), 'www';
            is its('mounted_on'), '/dev/sdb1';
            isnt its('writable');
        };
        context service("nginx"), sub {
            is its('ensure'), 'running';
        };
        context pkg("nginx"), sub {
            is its('ensure'), 'present';
            is its('version'), '1.5.8';
        };
        context cron, sub {
            like its('www'), 'logrotate';
        };
        context gateway, sub {
            is it, '192.168.0.1';
        };
        context group('www'), sub {
            ok its('ensure');
        };
        context port(80), sub {
            is its('bind'), '0.0.0.0';
            is its('proto'), 'tcp';
            is its('command'), 'nginx';
        };
        context process('nginx'), sub {
            like its('command'), qr(nginx -c /etc/nginx.conf);
            ok its('mem') > 1024;
        };
        context routes, sub {
            is_deeply its(1), {
                destination => $dest,
                gateway     => $gw,
                genmask     => $genmask,
                flags       => $flags,
                mss         => $mss,
                irtt        => $irtt,
                iface       => $iface,
            };
        };
        context sysctl, sub {
            is its('vm.swapiness'), 1;
        };
        context user('www'), sub {
            ok its('ensure');
            is its('home'), '/var/www/html';
            is its('shell'), '/sbin/nologin';
            is_deeply its('belong_to'), ['www', 'nogroup'];
        };
    };
    done_testing;
```

从 Rspec 学来的 context/describe/it/its 语法，保留了 Test::More 的 is/like/is_deeply/done_testing 语法。

这里把 Test::More 里导入的指令都重载了，因为把 context 指令后面的资源类型通过 `local $msg` 变量传递过来，就可以显示出来每个 `its` 测试是什么资源类型的了。因为这个原因，指令导出的时候就没法用 `Exporter` 模块，因为 Exporter 里的 import 函数没有 `no strict;no warnings`。所以得自己写 import 函数导出。

具体的资源类型，第一次学习了一下 AUTOLOAD 的用法。还是蛮好玩的~

因为我是在 Mac 上写的代码，而 Rex 本身不怎么支持 Darwin 平台，所以源码里就测了一下 run 指令可用。欢迎大家帮忙补齐其他指令的测试用例，以及如何在 Rex 的 task 里通过 SSH 方式远程做这些测试（公司平台也没法让我做这个 SSH 测试）。
