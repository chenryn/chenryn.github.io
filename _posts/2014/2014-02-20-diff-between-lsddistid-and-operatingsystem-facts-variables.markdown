---
layout: post
title: Facts 变量中 lsbdistid 和 operatingsystem 的区别
catagory: puppet
tags:
  - linux
  - ruby
---

Facts 变量是 puppet 里广泛使用的东西。在多种操作系统的混合环境中，通过 Facts 变量灵活定义不同的 package 名称、file 路径等应该是非常好用的办法。

不过关于操作系统，存在两类 Facts 变量，分别是 `lsbdistid` 和 `operatingsystem`。一般情况下，这两者结果基本一致，大家(至少我周围是)习惯采用 `operatingsystem` 这个一目了然的变量。

但是前两天发现有些机器的 puppet agent 运行失败，debug 后发现，居然是 `operatingsystem` 变量匹配不上！这台 CentOS 的服务器的 `operatingsystem` 结果是 OracleLinux！

翻看这两个变量的获取代码，他们的获取办法并不一致。

* `lsbdistid` 是通过运行 `lsb_release -i -s` 命令获取的；
* `operatingsystem` 是通过一串超长的 if-elif-else 逻辑来判断的。恰好其中探测 `/etc/oracle-release` 是否存在的步骤优先于探测 `/etc/redhat-release` 的步骤。

而这台服务器上，不知道怎么被人安装了一个 `oraclelinux-release-5-8.0.2` 的软件包，这个包里只有一个文件，就是 `/etc/oracle-release`！

这个软件包怎么出现的可以慢慢追查，但是这件事情本身提醒我们，`operatingsystem` 变量的获取方式过于简单，这些文本文件稍有问题可能就会导致错误。所以在只有 Linux 类服务器的情况，还是尽量确保所有节点都安装有 `lsb_release` 命令然后使用 `lsbdistid` 变量吧。

