---
layout: post
title: Newbie::Gift 所用知识总结
category: perl
---

通过 [Newbie::Gift](https://github.com/chenryn/Newbie-Gift) 项目的开发过程，学习和深入了解了不少 Perl 知识，虽然这个模块估计短期内不会再继续开发和更新了，不过还是值得记录一下这段过程中的心得。

### gensym

封装 `IPC::Open3` 模块时，通过 `smokeping` 代码中学到了 `Symbol` 模块的 `gensym` 指令的使用。

通过 `gensym` 指令可以直接返回一个临时文件句柄来使用。

### $cb->()

在 SPEC 设计中，所有导出指令都采用回调的方式。在 Perl 中实现起来其实特别简单。像下面这样就好了：

```perl
sub keyword {
    my ( $str, $cb ) = shift;
    my $res = do_some_func($str);
    $cb->($res);
}
```

### selector_to_xpath

之前一直有使用 `Mojo::UserAgent` 配合 `Mojo::DOM` 完成网页抓取工作，这次自己实践，参考的是另一个 [Web::Query](https://metacpan.org/module/Web::Query) 模块。其中最关键的两步，第一是通过 [selector_to_xpath](https://metacpan.org/module/HTML::Selector::XPath) 指令把选择器的写法转换成 XPath 语言；第二是通过 XPath 操作网页的 [HTML::Tree](https://metacpan.org/module/HTML::TreeBuilder::XPath)。

不过 `Mojo` 里对象化的很完整，返回的数组和字符串都是对象，所以可以一直反复调用方法连接起来处理，写的会很爽。用 `Web::Query` 没有这个效果。

### File::stat

stat 是 perl 默认的函数，不过返回的数组在 mode 和 time 方面可读性都不好，所以封装一下，提供更加可读的 0644 这样的 mode 格式，直接用 `sprintf` 就可以做到：

```perl
    sprintf( "%04o", $ret->get(2) & 07777 );
```

### DateTime

Perl 的 [DateTime](https://metacpan.org/module/DateTime) 模块太重，CPAN 上其实也有很多人提交简化版的 DT，其实就是利用 `localtime`，`strftime` 和 `mktime` 几个默认函数做出来的对象调用。

### Exporter

`import` 和 `export_to_level` 都是 `Exporter` 模块的方法，所有继承自 `Exporter` 的模块可以用。比如下面示例，启用该模块，就相当于启用了 `strict`，`warnings`，`utf8` 和 Perl5.10 版的新特性，同时导出了 keywords 关键字。

```perl
    use base 'Exporter';
    our @EXPORT = qw/keywords/;
    sub keywords { ... }
    sub import {
        my $class = shift;
        strict->import;
        warnings->import;
        utf8->import;
        feature->import(':5.10');
        Try::Tiny->import;
        $class->export_to_level(1, $class, @EXPORT);
    }
```

### zip

多数组可以通过 `zip` 命令逐一对位融合到一起。这个在 [List::MoreUtils](https://metacpan.org/module/List::MoreUtils) 中有，这次用 `NG::Array` 对象实现了一边，其原理是先记录每个数组的长度，然后以最长的那个数组为标杆，循环一遍即可。

### autobox

CPAN 上 Rubyish、Perl6::*、Perl5i::* 等模块都利用了 [autobox](https://metacpan.org/module/autobox) 实现完全的对象化。autobox 是一个库，本身不提供对象方法，而是要自己自己实现针对某个类型的对象方法后，通过 autobox 关联到 Perl 的数据类型上去。

比如想要实现一个 `"Hello World"->lc->words` 的语法，显然就是要针对 Perl 中的 STRING 数据类型实现 lc 和 words 两个方法。那么先实现一个自己的 string 对象：

```perl
    package your::string;
    sub lc    { CORE::lc           $_[0] }
    sub words { CORE::split /\s+/, $_[0] }
    1;
```

然后开始关联：

```perl
    package your::autobox;
    use base qw(autobox);
    use your::string;
    sub import {
        shift->SUPER::import(
            STRING => 'your::string',
            @_
        );
    }
    1;
```

最后在前面提到过的 `Exporter` 的 `import` 函数里加上一行：

```perl
    your::autobox->import;
```

autobox 可以关联的数据类型还有很多，绝对是值得一看的模块。


### eval('*'.$class.'::new')

实现 `def_class` 关键词的过程中学习颇多，首先是符号表。实现中完成模块代码几乎全靠符号表来绑定一个个函数和变量。像这样：

```perl
    *t = eval('*'.$class.'::ISA');
    *t = [$parent];

    *t = eval('*'.$class.'::new');
    *t = sub {
        my ($class, @args) = @_;
        push @args, '' if $#args % 2 == 0;
        my $o = bless {@args}, ref $class || $class;
        if(defined $methods->{build}){
            $o->build(@args);
        }
        $o;
    }
```

不过这个实现有个问题，就是对象只能是基于哈希的引用，不能是数组的了。

### 对象的元数据

实现 `def_class` 的时候比 spec 多新增了一个默认属性叫meta，所有用 `def_class` 实现的类，会自动记录他们(包括他们的用 `def_class` 实现的父类)的属性和方法到meta属性里。

为此阅读了一下 `Moo` 和 `Moos` 的代码。
__原来他们都是把属性和方法也实现为类。然后再有 `*::Meta` 类来记录这些属性和方法的类。__

而 `Newbie::Gift` 计划中没打算把对象化搞得这么彻底，所以就只是存了一个 hash 到 默认 meta 属性里。

### :lvalue

对象除了方法还要有属性，`def_class` 里也有实现，同样是用符号表绑定的。

不过这里用到了 Perl5.10 的一个新东西，函数属性，这里绑定的不是普通变量而是函数，但是函数只会读写一个变量值，具体的说就是使用 `sub :lvalue {}` 定义。使用方法如下所示：

```perl
    my $val;
    sub canmod :lvalue {
        # return $val; this doesn't work, don't say "return"
        $val;
    }
    sub nomod {
        $val;
    }
    canmod() = 5;   # assigns to $val
    nomod()  = 5;   # ERROR
```

lvalue 的说明见 `perldoc perlsub` 文档。在这里还是个比较有趣的用法的，这个用法来自 `Newbie::Gift` 项目另一位参与者 [fmpdceudy](https://github.com/fmpdceudy)。
