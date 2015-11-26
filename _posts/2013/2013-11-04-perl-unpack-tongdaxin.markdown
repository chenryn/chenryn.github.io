---
layout: post
title: 用 Perl 读取通达信日线数据
category: perl
---

之前看 skyline 的报警机制的时候，为了寻找测试数据，曾经想到是不是可以用股价走势。其实股价走势分析也是一个很深的编程领域，有些选股软件一份就好几千的卖。当然我这里没兴趣和时间搞那么复杂了。简单的说一下如何从通达信的存档里读取日线数据，说到底还是 `pack/unpack` 的运用：

```perl
#!perl
open my $fh, '<', 'C:\new_sxzq_v6\vipdoc\sh\lday\sh000001.day';
while ( sysread $fh, my $buf, 32 ) {
# 日期，开盘，最高，最低，收盘，成交金额，成交量，预留位
    my ( $date, $open, $high, $low, $close, $amount, $vol, $reserved ) =
      unpack( 'Ii4fi2', $buf );
    printf "%s %.2f %.2f %.2f %.2f %d %d\n", $date, $open / 100, $high / 100,
      $low / 100, $close / 100, $amount, $vol;
}
```

注意这里一定要一边 `sysread` 一边 `while`，否则一只股票的历史(上例中是上证指数)都没读完就会内存溢出的。
