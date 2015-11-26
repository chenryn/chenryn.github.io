---
layout: post
title: 从纯真数据库里获取ip列表
date: 2011-05-19
category: monitor
tags:
  - perl
---

首先申明只是一个简单的方式，因为打算的是提取总列表成bind9使用的acl格式，所以不在乎性能问题。
第一步、从CZ88.NET下载QQWry数据库，然后运行IP.exe，选择“解压”，然后会在桌面生成一个qqwry.txt，这里就有四十多万行的ip记录。格式如下：
起始ip    结束ip   大区域     小区域
但是这个大区域也不是想像中的那么整齐，比如清华大学宿舍楼也是大区域的……
好在我们DNS只需要一个大概的南北指向，根据电信占主流的现实，只要取出来联通的，其他都算电信就行了~
第二步、把起始ip-结束ip改成acl需要的子网掩码格式，这一步用perl完成，全文如下：
```perl
#!/usr/bin/perl -w
use Net::IPAddress::Util::Range;
while(<>){
    next unless $_ =~ /^(\S+)\s+(\S+)\s+(.+)/;
    my $range = Net::IPAddress::Util::Range->new({ lower => $1, upper => $2 });
    map {printf "%s\t%s\n", $_, $3 } $range->tight()->as_cidrs();
}
```
其中tight()->as_cidrs()其实是Net::IPAddress::Util::Collection的函数（Range.pm里use了这个函数）。tight将不规律的ip段划分成规律的子网，cidrs将类似(1.1.1.0 .. .1.1.1.255)改成1.1.1.0/24。
如果直接采用Net::IPAddress::Util::Range的$range->as_cidr()的话，它会把一个不规律的ip段取一个最近的规律子网来显示……比方1.59.0.0-1.60.149.255会被计算成1.57.0.0/13！！
不过这个还有一个问题，就是没有多行合并，导致条目太多~~这个之后再看吧~
