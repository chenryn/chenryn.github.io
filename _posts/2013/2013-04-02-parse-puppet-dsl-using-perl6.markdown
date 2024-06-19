---
layout: post
theme:
  name: twitter
title: 用 Perl6 解析 puppet 的配置语法
category: perl
tags:
  - puppet
  - perl6
---

前段时间看到报道说，puppet 的作者本来是用 perl 完成的原型设计，后来改用的 ruby。所以我想，目前这个 puppet 的 DSL 设计，用 perl 来完成的话，应该如何做。

这里碰到一个问题，就是 puppet 中 `resource_type` 的 `title` 后面有个冒号，这事儿比较麻烦，不过这时候我突然想到了 Perl6 ，稍微翻了一下文档，发现这事用 Perl6 来实现很容易：

```perl
use v6;

sub infix:<:>($a, %b){
    return $a, %b;
};

sub service(&service) {
    my @res = &service.();
    say @res.shift => @res.hash;
}

class nginx::install {
	my $nginxparams = "nginx";
	service { "$nginxparams":
        conf => "#",
        source => "http" 
    }
}
```

运行结果如下：

```perl
perl6 /data/perl6/script/puppet-style.pl
"nginx" => {"conf" => "#", "source" => "http"}
```

当然实际上 puppet 要复杂很多，这里其实更多是为了说明 Perl6 如何自定义操作符~
