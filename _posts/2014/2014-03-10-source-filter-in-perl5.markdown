---
layout: post
title: Perl5 的 Source Filter 功能
category: perl
---

去年在 [p5-mop-redux](https://github.com/stevan/p5-mop-redux) 项目里看到他们在 Perl5 里实现了 Perl6 的面向对象设计的很多想法，尤其下面这段示例让人印象深刻：

```perl
    use mop;

    class Point {
        has $!x is ro = 0;
        has $!y is ro = 0;

        method clear {
            ($!x, $!y) = (0, 0);
        }
    }

    class Point3D extends Point {
        has $!z is ro = 0;

        method clear {
            $self->next::method;
            $!z = 0;
        }
    }

    my $p = Point3D->new(x => 4, y => 2, z => 8);
    printf("x: %d, y: %d, z: %d\n", $p->x, $p->y, $p->z);
```

这种 `$!x` 的变量是怎么实现的？最近几天，又在 CPAN 上看到另一个模块叫 [Perl6::Attributes](https://metacpan.org/pod/Perl6::Attributes)，实现了类似的语法。于是点进去一看，实现原来如此简单！

```perl
package Perl6::Attributes;
use 5.006001;
use strict;
no warnings;
 
our $VERSION = '0.04';
 
use Filter::Simple sub {
    s/([\$@%&])\.(\w+)/
        $1 eq '$' ? "\$self->{'$2'}" : "$1\{\$self->{'$2'}\}"/ge;
    s[\./(\w+)][\$self->$1]g;
};
```

原来这里用到了 Perl5.7.1 以后提供的一个新特性，叫做 [Source Filters](https://metacpan.org/pod/distribution/Filter/perlfilter.pod) 。在解释器把 file 变成 parser 的时候加一层 filter。
