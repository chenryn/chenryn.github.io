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

