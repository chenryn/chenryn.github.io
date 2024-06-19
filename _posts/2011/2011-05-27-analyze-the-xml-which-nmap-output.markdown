---
layout: post
theme:
  name: twitter
title: nmap扫描结果xml解析脚本
date: 2011-05-27
category: monitor
tags:
  - nmap
  - perl
---

```perl#!/usr/bin/perl -w
use XML::Simple;
use Net::MySQL;
system("nmap -n -p 5666 10.1.1.0/23 10.1.3.0/24 -oX output.xml");
my $text = XMLin("output.xml");
my $i = 0;
while ( $text->{host}->[$i] ) {
    my $nrpe = $text->{host}->[$i]->{ports}->{port}->{state}->{state};
#因为在扫描到本机的时候，是没有mac的，所以到本机时不是ARRAY而是HASH
    my $ip = ref($text->{host}->[$i]->{address}) eq 'ARRAY' ? $text->{host}->[$i]->{address}->[0]->{addr} : $text->{host}->[$i]->{address}->{addr};
    my $mac = ref($text->{host}->[$i]->{address}) eq 'ARRAY' ? $text->{host}->[$i]->{address}->[1]->{addr} : '00:1E:C9:E6:E1:7C';
    &mysql_query($ip, $mac, $nrpe);
    $i++;
}
sub mysql_query {
my ($ip, $mac, $nrpe) = @_;
my $mysql = Net::MySQL->new( hostname => '10.1.1.25',
                             database => 'myops',
                             user     => 'myops',
                             password => 'myops',
                           );
$mysql->query(
"insert into myhost (intranet, mac, monitorstatus) values ('$ip', '$mac', '$nrpe')"
);
}```
小脚本一个，扫描内网网段内存活的机器，获取其MAC地址，以及nrpe端口情况。后期再配合myhost里的system，如果是linux（其实用nmap -O也可以获取system，但是结果不准，耗时还特别长，200台机器花10分钟），但monitorstatus还是closed的，就expect上去安装nrpe，嗯~~
