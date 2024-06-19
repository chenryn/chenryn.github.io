---
layout: post
theme:
  name: twitter
title: perl的POD权限问题
date: 2010-05-27
category: perl
---

今天继续查找mod_perl对req_header的处理。

一开始打算用perldoc看Apache2::Request模块，结果在运行时出现如下错误：

    Error in tempfile() using /tmp/XXXXXXXXXX:parent directory (./) is
    not writable at /usr/lib/perl5/5.8.8/Pod/Perldoc.pm line 1483.

改到/tmp/执行命令，还是报错。看来和PWD是没关系，跟/tmp本身的权限有关吧～～（因为我经常在/tmp下做试验，可能不知道什么时候无意就改了权限了）

chmod 777 /tmp

再执行命令，ok了～～

<hr />

在看过Apache2::Request的doc后，没有发现header相关的设定，决定去直接看apache的那些pm，不过之前只管CPAN哗哗安装了，可从来没管过它们都安装在哪里……

/usr/五六个目录都是perl的，找起来可真不是个容易事～（记得之前测试，perl脚本每次执行，都有好几百毫秒用来查找模块在什么位置……）

一时偷懒去百度了一下，很不错，看到CPAN常见问题集，正好有这个办法：

perl -MFile::Find=find -MFile::Spec::Functions -Tlwe 'find { wanted => sub { print canonpath $_ if /.pmz/ }, no_chdir => 1 }, @INC'

然后grep Apache，就看到结果了，都安装在/usr/lib64/perl5/site_perl/5.8.8/x86_64-linux-thread-multi/Apache2这个路径下。
进去grep '$r->header' *，立马就看出来，是RequestRec.pm里的。
