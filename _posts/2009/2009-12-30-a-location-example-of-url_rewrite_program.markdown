---
layout: post
title: url_rewrite_program（首次访问跳转）
date: 2009-12-30
category: squid
---

上文提到，squid大多数的rewrite_program是用perl编写的。现在就转几个简洁明了的redirect.pl。虽说我至今没把perl基础教程看完。不过从中领会一下squid的rewrite流程，还是可以的：

例一：这是最简单的url转向，把http://www.baidu.com/转到https://www.google.com:

```perl
#!/usr/bin/perl -w
$|=1;
while () {
    @X = split;
    $url = $X[0];
    if ($url =~ m#^http://www.baidu.com#) {
        print "302:http://www.google.com\n";
    } elsif ($url =~ m#^http://gmail.com#) {
        print "302:http://gmail.google.com\n";
    } else {
        print "$url\n";
    }
}
```

例二：这个的功效，是当第一次访问外网网站时，先跳转到公司主页一次，之后再访问就不再限制。

```perl
#!/usr/bin/perl -w
use strict;
use DB_File;
use vars qw (%cache $uri $cachetime);
$|=1;
my $timeout=3600;#缓存超时时间
while (){
    my ($client,$ident,$method)=();
    ($uri,$client,$ident,$method)=split;
    if (check($client)){
        next;
    }else{
        save($client);
        $uri="301:http://www.xxxx.cn";
    }
} continue {
    print $uri;
}

sub check {
    my $client=shift;
    # init cache time
    my $time=time();
    if (!$cachetime){
        $cachetime=$time+$timeout;
    }
    if ($time &gt; $cachetime){
        %cache=();
        $cachetime=();
    }
    return 1 if $cache{$client};
    # reopen db
    my %ip=();
    tie %ip,"DB_File","/tmp/ip.db",O_CREAT|O_RDWR,0666;
    %cache=%ip; #hard copy?
    untie %ip;
    $cache{$client} ? 1:0;
}

sub save {
    my $client=shift;
    my %ip=();
    tie %ip,"DB_File","/tmp/ip.db",O_CREAT|O_RDWR,0666;
    $ip{$client}=1;
    untie %ip;
}
```
