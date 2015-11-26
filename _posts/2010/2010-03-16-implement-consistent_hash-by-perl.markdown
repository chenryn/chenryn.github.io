---
layout: post
title: consistent_hash的perl脚本模拟
date: 2010-03-16
category: web
tags:
  - perl
---

```perl
#!/usr/bin/perl -w
use String::CRC32;

my $url = shift;
my @peer = ('10.13.12.14:80',
'10.13.12.15:80',
'10.13.12.16:80',
'10.13.12.17:80',
'10.13.12.18:80');
my $new = 9999999999;

my $sum = $#peer+1;
my $uricrc = crc32("$url",length($url));
for (my $i=0;$i<$sum;$i++) {
my $peercrc = crc32($peer[$i],length($peer[$i]));
my $res = $peercrc - $uricrc;
if ($res > 0 && $res < $new){
$new = $res;
$haha = "$i\t$new";
}
}
my @num = split(/\t/,$haha);
printf("%s cached at the %s peer by the key %010.0f.\n",$url,$peer[$num[0]],$uricrc);
_END_
```
测试如下：
```bash
./crc.pl http://www.hapi.com.cn/FLASH/age.swf
http://www.hapi.com.cn/FLASH/age.swf cached at the 10.13.12.14:80 peer by the key   1007905459.
```
方法很拙劣，在比较运算和数组传递之间捣腾了很久，最后还是没能用%var{}和sort的办法搞定，而是采用了赋值单一变量然后切割获取序号的办法，反正只是做个小模拟，~~

