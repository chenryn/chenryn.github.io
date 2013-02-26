---
layout: post
title: perl模块Statistics::Descriptive
date: 2011-06-09
category: perl
---

今天写基调测试报告，需要从原始的ping延时和丢包率数据中自己计算标准方差以评估波动性（直接运行ping命令可见，不过基调报告里没有）。
方差是各个数据与其平均数的差的平方的平均数。标准差（均方差）则是方差的算术平方根。
这个时候可以打开excel……不过作为excel只会填文字的人，只好打开CPAN来解决问题了~
{% highlight perl %}#!/usr/bin/perl -w
use Statistics::Descriptive;
use strict;
open FH,'<','data';
my $data={};
while(<FH>){
   my @F = split;
   push @{$data->{"快网延时"}}, $F[3];
   push @{$data->{"快网丢包"}}, $F[4];
   push @{$data->{"森华延时"}}, $F[6];
   push @{$data->{"森华丢包"}}, $F[7];
   push @{$data->{"帝联延时"}}, $F[9];
   push @{$data->{"帝联丢包"}}, $F[10];
}
close FH;
my $stat = Statistics::Descriptive::Full->new();
foreach my $key (sort keys %{$data}) {
    $stat->add_data(@{$data->{"$key"}});
    print $key."\t".$stat->standard_deviation(),"\n";
    $stat->clear();
}{% endhighlight %}
记住一定要clear，不然的话add_data会接着上一次的加，然后数据就错了。
