---
layout: post
theme:
  name: twitter
title: 用 plenv 代替 perlbrew 管理 Perl5
category: perl
tags:
  - bash
  - ruby
---

我们都知道有 virtualenv 啊，rvm 啊之类的工具来管理 python，ruby的多版本问题，后来台湾的朋友也引入到了 Perl 世界，这就是 perlbrew。

不过 perlbrew 在使用的时候，有个非常让我不理解的地方，就是切换 Perl 版本后，整个终端的环境变量都被清空了。后来发现了一个新项目，叫 plenv，没错，一眼就可以看出来这是 rlenv 工具的 Perl 版。

和 perlbrew 不一样，目前版本的 plenv 已经是一个纯粹的 shell 工具。说起来原先一直是 shell 工具的 rvm，这周却在募捐准备改用 Ruby 重写了(据说是因为已经 2 万行的 bash 代码，作者快控制不住了)。

用法非常简单：

```bash
git clone git://github.com/tokuhirom/plenv.git ~/.plenv
echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(plenv init -)"' >> ~/.bash_profile
exec $SHELL -l # 这步相当于退出重登录终端
git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/
plenv install 5.18.0
plenv rehash # 每次在 $HOME/.plenv/bin 下安装了新的命令后都要执行一次这个
plenv install-cpanm
plenv rehash
plenv shell 5.18.0 # 还有 global 和 local 两者可设
```

目前我已经用 plenv 管理自己电脑上的 Perl5 了，你们呢？
