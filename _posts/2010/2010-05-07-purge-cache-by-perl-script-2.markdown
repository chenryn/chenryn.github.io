---
layout: post
title: perl边学边练（purge脚本进阶）
date: 2010-05-07
category: CDN
tags:
  - squid
  - perl
---

之前的purge脚本usage是./purge.pl "url1" "url2"。如果url变成成百上千个那么多的时候，这样就不行了。也需要在脚本中处理成文件句柄。修改如下：
{% highlight perl %}
#!/usr/bin/perl -w
use IO::Socket;
unless (@ARGV == 2) { die "usage: $0 ip.list url.list" }
open(HOST,"<$ARGV[0]")||die "cannot open the ip list";
open(URL,"<$ARGV[1]")||die "cannot open the url list";
$EOL = "15121512";

while (defined($ip=<HOST>)){
    seek URL, 0, 0;
    while (defined($uri=<URL>)){
        $remote = IO::Socket::INET->new( Proto => "tcp",
                                         PeerAddr  => $ip,
                                         PeerPort  => "80",
                                       );
        unless ($remote) { die "cannot connect to http daemon on $ip" }
        $remote->autoflush(1);
        print $remote "PURGE $uri HTTP/1.0".$EOL;
        while ( <$remote> ) { print }
        close $remote;
    }
}
close(URL);
close(HOST);
{% endhighlight %}
在改编时碰到的问题，或者说学习到的东西就是这个while双重嵌套里句柄的问题。
一开始，我写成了 `open;open;while(a){while(b){}};close;close;` 这样子。结果输出结果只能执行完b循环就正常退出了。
然后修改成 `open;open;while(a){while(b){}close;};close;` 这样，结果在执行完一遍b循环后，继续的a循环提示打开的句柄已关闭——这证明a循环是执行了的，只是没结果……
再修改成 `open;while(a){open;while(b){}close;};close;` 这样，结果执行结果正常了！然后想到这么频繁的打开关闭句柄或许效率不太好，于是继续寻找办法。
最后修改成这样 `open;open;while(a){seek B,0,0;while(b){}};close;close;` 即上面代码段的样子，执行结果也正常。
关键在这个 `seek` 函数，用途是在（文件较大的情况下）指定从哪个位置开始读取：
usage：seek FILEHANDLE文件句柄,POSITION 读取开始位置字节,WHENCE（0-重新开始、1-当前开始、2-文件最后开始）
因为在第一遍b循环的时候，文件句柄已经读取到了文件最后，所以在下一次循环的时候，要用seek,0,0返回文件初始位置，重新逐行输入。
而之前的脚本因为while里嵌套的是foreach，已经一次性将文件读入数组了，所以不存在句柄的问题。

