---
layout: post
theme:
  name: twitter
title: PerlAPI 里的 Magic 简介
category: perl
---

前几天看到 cindylinz 发了一个新 CPAN 模块叫 [Scalar::Watcher](https://metacpan.org/pod/Scalar::Watcher)，有朋友问我这个是怎么实现的，在无限循环啊，多线程啊，IO 阻塞啊等情况下，还能被触发么？

于是我去仔细看了一下这个模块的代码。最关键的就是下面这几行：

```c
        SvUPGRADE(target, SVt_PVMG);
        sv_magicext(target, handler_cv, PERL_MAGIC_ext, &modified_vtbl, NULL, 0);
```

这里其实用的是 perlapi 里的 Magic：

* 第一行，设置监听变量为 `SVt_PVMG`，即带有 Magic 的标量；

  `SvUPGRADE` 函数见 perlguts 文档的 "[Assigning Magic](http://perldoc.perl.org/perlguts.html#Assigning-Magic)" 部分。

* 第二行，设置该变量的 Magic 扩展，即往标量的 Magic 链表上加内容。

  `sv_magicext` 函数说明见 perlapi 文档的 "[SV-Body Allocation](http://perldoc.perl.org/perlapi.html#SV-Body-Allocation)" 部分。

Magic 主要有两个作用，一个叫 Hook Method，一个叫 Managed Data。我们都很熟悉的 Moose 框架就是利用的 Magic 的 Managed Data 实现的。而这里，用到的是 Hook Method。

Scalar::Watcher 模块文档较少，虽然好用但是不好懂。我在 CPAN 上发现另一个模块，[Variable::Magic](https://metacpan.org/pod/Variable::Magic) 。文档写的很详细。其中的 `set` 方法就是跟 Scalar::Watcher 类似的作用，大家可以读一读这个模块的文档。

所以可以回答朋友的问题了，在循环之类的地方每次都可以触发没问题。但是如果你在回调函数里面做阻塞操作，那肯定也是堵塞的。
