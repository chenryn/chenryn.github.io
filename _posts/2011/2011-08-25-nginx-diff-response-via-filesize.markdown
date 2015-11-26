---
layout: post
title: 用nginx区分文件大小做出不同响应
date: 2011-08-25
category: nginx
tags:
  - perl
---

昨晚和前21v的同事聊天，说到我离职后一些技术上的更新。其中有个给某大客户(游戏下载类)的特殊需求设计，因为文件大小差距很大——估计是大版本和补丁的区别——又走的是同一个域名，而squid在响应比较大的文件时，尤其是初次下载的时候，性能比较差，所以拆成两组服务器，squid服务于较小的文件，通过pull方式从peer层获取，nginx服务于较大的文件，通过push方式由peer层分发同步。外部发布域名一律解析到squid服务器组上，请求透传到peer层的nginx，nginx分析这个url的content-length，如果大于阈值，则不返回文件，而是302到nginx服务器组的独立域名下的相应url去。

这里要注意的是，nginx的内部变量里有一个$content-length，是不能用在这里的，官方wiki是这么解释这个变量的："This variable is equal to line Content-Length in the header of request"。可见，这个变量是请求头的内容，一般见于POST请求用来限定POST信息的长度；而不是我们需要的响应头的内容。

老东家最后是修改了nginx的src完成的功能。不过我想，这里其实可以使用http_perl_module完成的。而且还可以扩展302跳转的功能，把独立域名改成直接通过remote_addr定向到最近IP上。

因为手头没有服务器，以下内容都是凭空想象，看官们注意……
首先是nginx.conf里的配置：
```nginxhttp {
    perl_modules perl;
    perl_require SizeDiff.pm;
    server {
       listen       80;
       server_name  dl.gamedomain.com;
       location / {
          perl SizeDiff::handler;
       }
    }
}```
然后是perl/SizeDiff.pm，如下：
```perlpackage SizeDiff;
use Nginx::Simple;
sub main {
    my $self = shift;
    my $webroot = '/www/dl.gamedomain.com/'
    return HTTP_NOT_ALLOWED unless $self->uri =~ m!^(/.+/)[^/]+$!;
    my $file = $webroot . $1 . $self->filename;
    my @filestat = stat($file) or return HTTP_NOT_FOUND;
    my $filesize = $filestat[7];
    if ( $filesize < 8 * 1024 * 1024 ) {
        return OK;
    } else {
        $self->location('http://bigfile.cdndomain.com'.$self->uri);
    }
};
1
```
大体应该就是上面这样。
之前还考虑过如果不是push方式，可以在perl里考虑使用LWP获取header，不过仔细想想：第一，万一源站开启了chunked获取不到content-length呢？第二，就算可以，如果一个文件是1个G，那再去下载这1个G的文件下来，这个perl进程肯定挂了——官方wiki里可是连DNS解析时间都认为太长……也就是说，这个设想不适合在peer层，而是在loadbalance的角色，通过lwp的header结果，小文件upstream到后端的squid，大文件location到另外的nginx。
另一个可改进的地方，就是self->location前面，可以结合Net::IP::Match::Regexp模块或者自己完成的类似功能，来针对self->remote_addr选择最近的服务器组IP，最后返回location("http://$ip$uri")这样。
