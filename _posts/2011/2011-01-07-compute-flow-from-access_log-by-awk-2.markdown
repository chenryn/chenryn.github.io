---
layout: post
theme:
  name: twitter
title: 日志计算(awk进阶)
date: 2011-01-07
category: bash
tags:
  - awk
---

曾经用awk写过一个日志流量计算的单行命令。因为awk中没有sort函数，所以在中途采用了|sort|的方式，导致效率很低。在计算50GB+的日志时，运算时间慢的不可忍受。

设想了很多方法来加快运算，比如舍弃awk改用perl来完成，如下：
```perl#!/usr/bin/perl
use warnings;
use strict;
my $access_log = $ARGV[0];
my $log_pattern = qr'^.*?:(\d\d:\d\d):(\S+\s){5}\d+\s(\d+).+';
my %flow;
my ($traffic, $result) = (0, 0);
open FH,"< $access_log" or die "Cannot open access_log";
while (defined(my $log = <FH>)) {
    $flow{$1} += $3 if $log =~ /$log_pattern/;
    #print $1." ".$3." ".$flow{$1} * 8 / 300 / 1024 / 1024,"\n";
}
close FH;
foreach my $key ( sort keys %flow ) {
    my $minute = $1 if $key =~ /\d\d:\d(\d)/;
    $traffic += $flow{$key};
    if ( $minute == '0' or $minute == '5' ) {
        $result = $traffic if $traffic > $result;
        $traffic = '0';
    }
}
print $result * 8 / 300 / 1024 / 1024;
```
好吧，这个正则太过垃圾，请无视，但至少在管道和系统sort上浪费的时间还是大大的节省了的。

然后在CU上翻到一个老帖子，提供一个比较不错的awk思路，命令如下：

```bash
awk '!b[substr($4,14,5)]++{print v,a[v]}{v=substr($4,14,5);a[v]+=$10}END{print v,a[v]}'
```

这里用substr()跟指定FS相比那个效率高未知，不过采用!b++的方式来判断某时间刻度结束，输出该时刻总和，在顺序输入日志的前提下，运算速度极快（就剩下一个加法和赋值了）。

注意：此处b[]内不能偷懒写v，!b[v]++永远只会输出时刻的第一行数值。

不过真实使用时不尽如人意。逻辑上推导了很久没发现问题，结果在重新运行前面的perl时看了看while中的print，发现这个日志因为是从各节点合并出来的日志，其时间并不是顺序排列的！！

另，刚知道gawk3.1以上提供了asort()和asorti()函数，可以研究一下~

采用time命令测试一下
```bash
gawk '{a[substr($4,14,5)]+=$10}END{n=asorti(a,b);for(i=1;i<=n;i++){print b[i],a[b[i]]*8/60/1024/1024}}' example.com_log | awk '{if($2>a){a=$2;b=$1}}END{print b,a}'
```

一个35G的日志文件只用了6分钟。

然后更简单的
```bash
gawk '{a[substr($4,14,5)]+=$10}END{n=asort(a);print a[n]*8/60/1024/1024}' example.com_log
```

不过简单的运行发现只比前一种快不到10秒钟。而前一种还能输出峰值的时间，可读性更好一些~
