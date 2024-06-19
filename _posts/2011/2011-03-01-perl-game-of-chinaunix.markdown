---
layout: post
theme:
  name: twitter
title: CU的perl大赛
date: 2011-03-01
category: perl
---

原帖地址：http://bbs.chinaunix.net/thread-1860259-1-1.html
刚看到帖子，试着自己做做，首先必须承认做的过程是重新去翻过资料了……

1. ```perl#!/usr/bin/perl  myfunc {
# $x = ...
return $x?1:undef;
}```

2. $x=()就是给$x赋了个undef；列表在标量上下文中取列表的最后一个元素；()是创建一个空列表；至于为啥取最后一个的原因，我猜测是采用的pop操作，所以从列表最后取值吧。

3. ```perl@x=(1,2,3,5,6,7,8);
@y=@z=();
for (0..$#x) {
    push @y, $x[$_] if $x[$_+1]-1 != $x[$_];
    push @z, $x[$_] if $x[$_-1]+1 != $x[$_];
}
for (0..$#z) {
    print $z[$_]."-".$y[$_];
    print "," unless $_ == $#z;
}```

4. 基本没用过@x[1]这个写法啊，猜测与$x[1]的区别会是在上下文上吧？一个标量一个列表。反正就这个题目的例子，print结果都是7

5. 汗，不知道print `ls -lta`;算不算最短perl代码？

6. ```perl@x=(..)
for (@x) {
    $sum += $_;
}
$avg = $sum / @x;
for (@x) {
    print "$_ " if $_ > $avg;
}```

7. ```perl$x = int(1 + rand 100);
while (<>) {
    chomp;
    exit unless /\d+/;
    print "Too low\n" and next if $_ < $x;
    print "Too high\n" and next if $_ > $x;
    print "Right" and exit if $_ == $x;
}```

8. 不知道啥是无阻塞IO……
