---
layout: post
title: 续上：合并纯真ip段
date: 2011-05-20
category: monitor
tags:
  - perl
---

上篇提到纯真ip库有很多行是浪费的，比如下面这种：```yaml
223.214.0.0     223.215.255.255 安徽省 电信
223.216.0.0     223.219.255.255 日本
223.220.0.0     223.220.162.1   青海省 电信
223.220.162.2   223.220.162.2   青海省海东地区 平安县九歌网吧
223.220.162.3   223.221.255.255 青海省 电信```
很简单的223.220.0.0-223.221.255.255段，却被拆成了三行。于是在通过起始ip结束ip计算子网之前，还需要合并一下这些ip段。
因为涉及ip比对，所以第一反应想到了mysql里有的inet_aton函数，去CPAN上搜了一下，发现有NetAddr::IP::Util模块有inet_aton函数，结果一用，发现居然生成的不是数字……于是从网上找到了pack的办法，如下：
```perl#!/usr/bin/perl -w
while(<>){
    next unless $_ =~ /^(\S+)\s+(\S+)\s+(\S+)/;
    my $low = unpack('N',(pack('C4',(split( /\./,$1)))));
#下面这行是IP::QQWry模块里的写法
#    print $1 * 256**3 + $2 * 256**2 + $3 * 256 + $4 if $1 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;;
    my $high = unpack('N',(pack('C4',(split( /\./,$2)))));
    next if $low == $high;
    my $addr = $3;
    unless ( $hash->{$addr}->{high}->[0] ) {
        $hash->{$addr}->{low}->[0] = $low;
        $hash->{$addr}->{high}->[0] = $high;
        next;
    };
#如果中间就隔几个ip的，可以无视之，合并就是了……
    if ( $low - $hash->{$addr}->{high}->[0] < 16 ) {
        $hash->{$addr}->{high}->[0] = $high;
        next;
    };
    unshift @{$hash->{$addr}->{low}}, $low;
    unshift @{$hash->{$addr}->{high}}, $high;
};
foreach $addr ( keys %{$hash} ) {
    my $i = 0;
    while ( $hash->{$addr}->{low}->[$i] ) {
        print $addr . "\t" . &nota($hash->{$addr}->{low}->[$i]) . "\t" . &nota($hash->{$addr}->{high}->[$i]) , "\n";
        $i++;
    }
};
sub nota {
    my $aton = shift;
    @a = unpack('C4',(pack('N',$aton)));
    return (join "\.",@a);
};```
pack真复杂，基本看不懂perldoc，唉……

最后汇报一下运行结果：
合并前一共428452行，合并后103008行。
