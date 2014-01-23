---
layout: post
title: 计算两个时间点之间隔了几天
category: perl
---

两个时间点字符串，像这样：`2013-06-21`，怎么计算相距多少天呢？

有两种办法。

## DateTime 模块

{% highlight perl %}
use DateTime;
use List::MoreUtils qw(zip);
use Data::Dumper;
print Dumper(
    DateTime->new( zip @{ [qw/year month day/] },
        @{ [ split /-/, '2013-06-21' ] } )->subtract_datetime(
        DateTime->new(
            zip @{ [qw/year month day/] },
            @{ [ split /-/, '2012-05-20' ] }
        )
        )->deltas
);
{% endhighlight %}

缺点是 `DateTime::Duration` 的 `days()` 只能返回进位 `months()` 之后剩余的天数。所以这里只能输出整个 `deltas()` 来看。

## timestamp 时间戳

{% highlight perl %}
use POSIX qw(mktime);
sub trans {
    my @str = split /-/, shift;
    mktime(
        0, 0, 0, $str[2],
        $str[1] - 1,
        $str[0] - 1900,
    );
}
my $dt1 = trans('1999-05-21');
my $dt2 = trans('2013-06-26');
print( ( $dt2 - $dt1 ) / ( 60 * 60 * 24 ) );
{% endhighlight %}

这里就是要注意，`mktime` 里的 `month` 是以 0 开始的，`year` 是从 1900 开始的。

------------------------------------------------------------------------------------------

__2014 年 01 月 22 日更新：__

在2013 年底的 advent calendar 和 perlmaven 上学习到了另外两个模块，这里补充一下：

## Time::Piece 模块

这个模块是 Perl5 的corelist 模块，所以不用另外安装就能使用：

{% highlight perl %}
use Time::Piece;
my $t1 = Time::Piece->strptime('2013-06-26', '%Y-%m-%d');
my $t2 = Time::Piece->strptime('2012-06-21 GMT', '%Y-%m-%d %Z');
print +($t1 - $t2)->days;
{% endhighlight %}

Time::Piece 模块重载了加减号，所以直接两个时间相减后就得到了 Time::Seconds 对象，然后调用 `days` 方法返回具体天数就可以了。

这里有个奇怪的问题，在采用 `strptime` 方法解析创建对象的时候，`%Z` 格式似乎除了 `GMT` 之外写其他的都会爆出：

    Error parsing time at /usr/lib/perl/5.14/Time/Piece.pm line 469.

这个真的很诡异了。

__2014 年 01 月 23 日补充：__

去看了一下 [Piece.xs](https://github.com/rjbs/Time-Piece/blob/master/Piece.xs) 的内容，发现虽然文档上说是学习的 [FreeBSD 的 strptime](http://www.opensource.apple.com/source/libc/libc-583/stdtime/strptime-fbsd.c) 实现，但是差的也太多了～直接里面 `_strptime` 函数关于时区的就一个 `*got_GMT` 真假判断 ==!

完整的 strptime 见 [POSIX::strptime](https://metacpan.org/pod/POSIX::strptime) 模块，或许我可以写一个扩展？

## DateTime::Moonpig 模块

这个模块是最近出的，属于 DateTime 模块的接口封装和优化。

{% highlight perl %}
use DateTime::Moonpig;
my $t3 = DateTime::Moonpig->new(year => 2013, month => 6, day => 26, time_zone => 'America/New_York');
my $t4 = DateTime::Moonpig->new(year => 2012, month => 6, day => 21, time_zone => 'GMT');
print int( ($t3 - $t4) / (60 * 60 * 24) );
{% endhighlight %}

从示例可以看出两点优化：

1. 可以灵活调整 DateTime::Moonpig 对象的时区，而不用分别 `use DateTime;use DateTime::TimeZone`；
2. 直接加减返回的不再是那个不好用的 `DateTime::Duration` 对象而是秒数。
