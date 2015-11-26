---
layout: post
title: Perl 的 overload 妙用
category: perl
tags:
  - mojolicious
  - OOP
---

在使用 Mojolicious 的时候，通常我们会发现一个很有趣的现象。

```perl
use ojo;
say g('http://www.baidu.com')->dom->at('script');
say g('http://www.baidu.com')->dom->at('script')->text;
```

这里可以看到，在用 `at()` 方法之后得到的结果，如果从上一行解读，似乎应该是一个字符串；但是从下一行解读，又还是一个对象，可以继续调用 `->text` 属性。

Perl 本身不是一个纯对象式的语言，字符串本身是没有对象属性的。而直接打印对象的话，应该输出的是类似 `Mojo::DOM->HASH(0x1234567)` 的效果。那这个效果是怎么实现的呢？

翻了 Mojo 的代码之后，发现原来 Mojo 里是把字符串、数组等都实现成了对象，分别是 `Mojo::ByteStream` 和 `Mojo::Collection` 两个类。然后再实现中，运用了 `overload` 来实现这个效果。代码很简单，`Mojo::ByteStream` 里是这样的：

```perl
use overload '""' => sub { shift->to_string }, fallback => 1;
sub to_string { ${$_[0]} }
```

此外， `Mojo::DOM`，`Mojo::URL`，`Mojo::JSON` 等十多个类中都用了这个方法。

看起来似乎还不是很明了，再贴两段 [overload 的 POD](http://perldoc.perl.org/overload.html) 就清楚了：

    It also defines an anonymous subroutine to implement stringification: this is called whenever an object blessed into the package Number is used in a string context...
    For example, the subroutine for '""' (stringify) may be used where the overloaded object is passed as an argument to print,...

这下清楚了吧。一旦在某个类里 `overload` 了双引号，那么这个类的对象在标量环境下调用的时候就会先调用这个函数。最典型的例子就是用在 `print` 的时候。

下面我们可以自己也试试：

```perl
package Test 0.01 {
    use overload '""' => sub { join " overloaded.\n", @{+shift} };
    sub new { bless [@_[1 .. $#_]], shift };
}
my $obj = new Test(1, 3, 2);
print $obj;
```

输出结果：

    1 overloaded.
    3 overloaded.
    2
