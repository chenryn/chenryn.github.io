---
layout: post
title: Perl 和 Python 的 pack 函数格式字符的区别
category: perl
tags:
  - monitor
  - moosefs
  - python
---

MooseFS 是运用很广泛的一个分布式文件系统，其自带有一个 python 写的 CGI 页面，可以查看集群状态。不过对于运维来说，这就不太方便纳入 nagios 等其他现有的监控体系中。好在既然它的 CGI 是 python 写的，那么自己照样临摹出一个监控脚本也不是太复杂。

其实整个数据是由 master 的 9421 端口进行 TCP 交互获取的，不过比较麻烦的是并不是普通文本流。CGI 中采用了 pack/unpack 函数来处理 TCP 包。根据数据的前 8 字节确定数据总长度和 MooseFS 的版本，然后依照不同版本的 pack 方式来 unpack 剩余内容。

笔者熟悉 Perl，所以就准备将这个处理流程改用 Perl 完成。结果发现原来 pack/unpack 在 Perl 和 Python 中，写法是不一样的。以 MooseFS 的 info 信息读取代码为例，Python 版如下：

{% highlight python %}
s = socket.socket()
s.connect((masterhost, masterport))
mysend(s, struct.pack(">LL", 510, 0))
header = myrecv(s, 8)
cmd, length = struct.unpack(">LL", header)
if cmd == 511 and length == 76:
    data = myrecv(s, length)
    v1, v2, v3, memusage, total, avail, trspace, trfiles, respace, refiles, nodes, dirs, files, chunks, allcopies, tdcopies = struct.unpack(">HBBQQQQLQLLLLLLL", data)
    ver = '.'.join([str(v1), str(v2), str(v3)])
{% endhighlight %}

而 Perl 版最终写完是这样的：

{% highlight perl %}
my $s = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto    => 'tcp',
);
my ($header, $data);
print $s pack('(LL)>', 510, 0);
sysread $s, $header, 8;
my ($cmd, $length) = unpack('(LL)>', $header);
if ( $cmd == 511 and $length == 76 ) {
    sysread $s, $data, $length;
    my ($v1, $v2, $v3, $memusage, $total, $avail, $trspace, $trfiles, $respace, $refiles, $nodes, $dirs, $files, $chunks, $allcopies, $tdcopies) = unpack('(SCCQQQQLQLLLLLLL)>', $data);
    my $ver = "$v1.$v2.$v3";
};
{% endhighlight %}

不同处主要有两点：

1. 关于 `big-endian` 定义的 `>` 符号位置不同，Python 里写在起首一次性全部生效；Perl 里需要每个格式符单独定义，或者采用括号合起来总定义；
2. Python 里的 `H` 格式符表示 `unsigned short`，在 Perl 里应该是 `S`；Python 里的 `B` 格式符表示 `unsigned char`，在 Perl 里应该是 `C`。

翻看了一下，在 PHP 和 Ruby 中，格式符定义和 Perl 是一样的，不清楚为什么 Python 这么特殊==!

各语言关于 `pack` 格式符的文档链接如下：

1. <http://www.w3school.com.cn/php/func_misc_pack.asp>
2. <http://www.kuqin.com/rubycndocument/man/pack_template_string.html>
3. <http://docs.python.org/2/library/struct.html>
4. <http://perldoc.perl.org/functions/pack.html>
