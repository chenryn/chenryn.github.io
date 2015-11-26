---
layout: post
title: spread试验
date: 2011-06-09
category: perl
---

spread还是半年前的时候偶然看到的，一直没有试过。前段时间用gearman收集集群日志时，发现gearman的方式，worker不会知道client来自哪里，一条job只会一个worker来做，比较适合做分布式计算，但相比我最初设想的实时系统管理需求，还是有一定距离。于是重新翻出来spread，感觉可以根据应用系统设置不同的group，然后统一再由一个回收结果的group即可。于是有了如下试验：

* spread安装配置：

```bashwget http://www.spread.org/download/spread-src-4.1.0.tar.gz
tar zxvf spread-src-4.1.0.tar.gz
cd spread-src-4.1.0
./configure --prefix=/usr/local/spread && make && make install
cat > /usr/local/spread/etc/spread.conf << EOF
Spread_Segment  10.1.171.255:4804 {
        ct-142                  10.1.168.142
        ct-94                   10.1.168.94
        ct-241                  10.1.168.241
        ct-156                  10.1.168.156
        ct-70                   10.1.170.70
        cnc-64                  10.1.169.64
        cnc-80                  10.1.169.80
        cnc-72                  10.1.169.72
        cnc-58                  10.1.169.58
}
EOF
groupadd spread
useradd -g spread spread
mkdir -p /var/run/spread
chown spread:spread /var/run/spread
echo '/usr/local/spread/lib' > /etc/ld.conf.d/spread.conf && ldconfig
#必须用-n指定配置文件中定义好了的servername；
#奇怪的是网上别的文章都指出这些配置要同时写入hosts，但我没写也一样用了
/usr/local/spread/sbin/spread -c /usr/local/spread/etc/spread.conf -n ct-156 &```

* perl的spread使用

CPAN上有很多关于spread的模块，试了几个后，选中了Spread::Messaging::Content。使用如下：
```perl#!/usr/bin/perl -w
use Spread::Messaging::Content;
use Event;

$spread = Spread::Messaging::Content->new(
     -port => "4804",
     -timeout => "10",
     -host => "10.1.168.156",
 );
$spread->join_group("test");
#当spread的group存在了filedescriptor后，执行子函数；
#$spread->fd来自Spread::Messaging::Transport，这个module是Spread::Messaging::Content自动加载调用的
Event->io(fd => $spread->fd, cb => \&put_output);
Event::loop();

sub put_output {
    $spread->recv();
    printf("Sender      : %s\n", $spread->sender);
    printf("Groups      : %s\n", join(',', @{$spread->group}));
    printf("Message     : %s\n", ref($spread->message) eq "ARRAY" ? 
                                     join(',', @{$spread->message}) :
                                     $spread->message);
}```
```perl#!/usr/bin/perl -w
use Spread::Messaging::Content;
$spread = Spread::Messaging::Content->new(
     -port => "4804",
     -timeout => "10",
     -host => "10.1.168.156",
 );

 $spread->group("test2");
 $spread->type("0");
 $spread->message("cooking with fire");
 $spread->send();```

* spread自带的spuser使用

```bash/usr/local/spread/bin/spuser -s 4804
j test
m test```
