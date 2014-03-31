---
layout: post
title: perl边学边练（purge脚本）
date: 2010-03-30
category: CDN
tags:
  - perl
  - squid
---

squid的purge，一般有两种方式，squidclient -m purge url或者http request (method)purge url。如果任务不太多的情况下，直接使用squidclient -p 80 -h 1.2.3.4 -m purge url即可。如果任务比较繁重的情况下，telnet80后直接发送purge请求稍微好一些。作为初学perl的练手，写一个purge脚本。如下：

{% highlight perl %}
#!/usr/bin/perl -w
use IO::Socket;
#检测脚本参数个数
unless (@ARGV > 0) { die "usage: $0 url" }
#打开ip列表文件，定义文件句柄HOST
open(HOST,"./ip");
#定义连接结束符，然后翻倍（汗这个方式~）
$EOL = "1512";
$BLANK = $EOL x 2;
#从打开的文件中读取具体ip
#@host = HOST;
#my $ip;
#foreach $ip(@host){
#当ip列表较大时，采用@host的方法可能out of memory，所以采取逐行读取
while (defined($ip=<HOST>)){
    #从参数中默认读取url变量
    foreach $document ( @ARGV ) {
        #利用IO::Socket::INET模块定义TCP80连接，port可以读取/etc/services文件里的定义
        $remote = IO::Socket::INET->new( Proto     => "tcp",
                                         PeerAddr  => $ip,
                                         PeerPort  => "http(80)",
                                       );
        unless ($remote) { die "cannot connect to http daemon on $ip" }
        #立即输出
        $remote->autoflush(1);
        #向定义的TCP连接文件句柄发送purge请求
        #这里可以直接"\n\n"，不过采用"".$BLANK的方式可能规范一些，因为在win或者mac的平台上，是不一样的
        print $remote "PURGE $document HTTP/1.0" . $BLANK;
        while ( <$remote> ) { print }
        #关闭tcp连接
        close $remote;
    }
}
#关闭ip列表文件
close(HOST);
{% endhighlight %}

