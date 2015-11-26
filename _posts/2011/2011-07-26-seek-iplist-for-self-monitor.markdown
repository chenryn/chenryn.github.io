---
layout: post
title: cdn自主监控(二):快速查找ip对应信息
date: 2011-07-26
category: monitor
tags:
  - perl
---

话接上篇，ip整理出来，然后就是接一个ip地址，快速定位查找到它属于哪个ip段，然后返回具体的省份和运营商。因为之前的ip已经转换成数字，而且是顺序排列的，所以可以采用折半算法(二分法)。perl脚本如下：
```perl#!/usr/bin/perl -w
#my $ip = inet_aton("$ARGV[0]");
my $ip = inet_aton(get_test_ip());
my $file = $ARGV[1] || 'iplist.txt';
my $length = `cat $file | wc -l`;

my $code = get_area_code('quhao.txt');
my @isplist = qw('其他' '电信' '联通' '移动' '教育网');

open my $fh, '<', "$file" or die "Cannot open $file\n";
my $line_len = '26';                       #=10+10+4+1+1，包括回车符(注意上篇输出为了好看多了空格，可以删掉) 
my $first = 0;
my $last = $length - 1;                    #统一使用SEEK_SET,所以最后一行的起始位置是length-1 
my $result = 1;
while ($result) {
    my $middle = sprintf("%.0f",($last-$first) / 2 + $first);    #折半位置，除法取整时采用sprintf比直接int精确
    seek $fh, $line_len * $middle, 0;                            #移动到折半位置 
    sysread $fh, $begin_ip, 10;                                  #从折半处读取10位 
    sysread $fh, $end_ip, 10;                                    #接着再读10位,如果没删空格,还要先seek移动1位,麻烦 
    #根据比大小决定下次向哪个方向折半
    if ( $ip < $begin_ip ) {
        $last = $middle;
        next;
    } elsif ( $ip > $end_ip ) {
        $first = $middle;
        next;
    } else {
    #找到相应区间，读取区号和运营商号
        sysread $fh, $area, 4;
        sysread $fh, $isp, 1;
        printf "%010s %s %s\n", $ip, $code->{"$area"}, $isplist[$isp];
        $result = 0;                                             #设定$result为假，退出循环 
    };
};

close $fh;

sub inet_aton {
    my $ip = shift;
    my $short = sprintf "%010s", $1 * 256**3 + $2 * 256**2 + $3 * 256 + $4 if $ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
    return $short;
};
#对应区号和省份，跟上篇的kv相反
sub get_area_code {
    my $file = shift;
    my $area_code = { '0000' => 'other' };
    open my $fh,'<',"$file" or die "Cannot open $file";
    while (<$fh>) {
	chomp;
        my($area,$code) = split;
	$area_code->{"$code"} = "$area";
    }
    close $fh;
    return $area_code;
};
#生成一个随机的合法ip地址
sub get_test_ip {
    return join '.', map int rand 256, 1..4;
}```

