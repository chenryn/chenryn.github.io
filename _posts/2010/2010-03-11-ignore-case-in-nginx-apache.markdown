---
layout: post
theme:
  name: twitter
title: 忽略大小写（nginx|apache）
date: 2010-03-11
category: nginx
tags:
  - nginx
  - apache
  - perl
---

看了看nginx的perl_module，差不多知道了个大概。
在nginx.conf的http域中，通过perl_modules指定模块路径，perl_require指定模块名称；location域中通过perl引用函数。
引用对象为$r->**，列举一下主要的参数：
    ·$r->args - 返回请求的参数。
    ·$r->discard_request_body - 告诉nginx忽略请求主体。
    ·$r->filename - 更具URI的请求返回文件名。
    $r->has_request_body(function) - 如果没有请求主体，返回0，但是如果请求主体存在，那么建立传递的函数并返回1，在程序的最后，nginx将调用指定的处理器。
    ·$r->header_in(header) - 检索一个HTTP请求头。
    ·$r->header_only - 在我们只需要返回一个应答头时为真。
    ·$r->header_out(header, value) - 设置一个应答头。
    ·$r->internal_redirect(uri) - 使内部重定向到指定的URI，重定向仅在完成perl脚本后发生。
    ·$r->print(args, ...) - 为客户端传送数据。
    ·$r->request_body - 在请求主体未记录到一个临时文件时为客户返回这个请求主体。为了使客户端的请求主体保证在内存里，可以使用client_max_body_size限制它的大小并且为其使用的缓冲区指定足够的空间。
    ·$r->request_body_file - 返回存储客户端需求主体的文件名，这个文件必须在请求完成后被删除，以便请求主体始终能写入文件，需要指定client_body_in_file_only为on。
    ·$r->request_method - 返回请求的HTTP动作。
    ·$r->remote_addr - 返回客户端的IP地址。
    ·$r->rflush - 立即传送数据到客户端。
    ·$r->sendfile(file [, displacement [, length ] ) - 传送给客户端指定文件的内容，可选的参数表明只传送数据的偏移量与长度，精确的传递仅在perl脚本执行完毕后生效。
    ·$r->send_http_header(type) - 为应答增加头部，可选参数“type”在应答标题中确定Content-Type的值。
    ·$r->sleep(milliseconds, handler) - 设置为请求在指定的时间使用指定的处理方法和停止处理，在此期间nginx将继续处理其他的请求，超过指定的时间后，nginx将运行安装的处理方法，注意你需要为处理方法通过一个reference，在处理器间转发数据你可以使用$r->variable()。
    ·$r->status(code) - 设置HTTP应答代码。
    ·$r->unescape(text) - 以%XX的形式编码text。
    ·$r->uri - 返回请求的URI。
    ·$r->variable(name[, value]) - 返回一个指定变量的值，变量为每个查询的局部变量。

nginx本身关于该模块的例子不多。除了官网<a href="http://www.freebsdsystem.org/doc/nginx_zh/OptionalHTTPmodules/EmbeddedPerl.html" target="_blank">三个用法举例</a>外，我只在一个博客上看到另<a href="http://hi.baidu.com/ywdblog/blog/item/172010d1c8de0dd5572c8487.html" target="_blank">一个用perl记录log的例子</a>。好在apache的perl例子很多，大约可以参见一下：
在<a href="http://perl.apache.org/docs/1.0/guide/snippets.html" target="_blank">mod_perl:Code Snippets</a>中关于mod_rewrite的两个举例：
```perl
package Apache::MyRedirect;
use Apache::Constants qw(OK REDIRECT);
use constant DEFAULT_URI => 'http://www.example.org';
sub handler {
    my $r    = shift;
    my %args = $r->args;
    my $path = $r->uri;
    my $uri = (($args{'uri'}) ? $args{'uri'} : DEFAULT_URI) . $path;
    $r->header_out(Location => $uri);
    $r->status(REDIRECT);
    $r->send_http_header;
    return OK;
}
_END_
package My::Trans;
use Apache::Constants qw(:common);
sub handler {
    my $r = shift;
    my $uri = $r->uri;
    my ($id) = ($uri =~ m|^/articles/(.*?)/|);
    $r->uri("/articles/index.html");
    $r->args("id=$id");
    return DECLINED;
}
1;
_END_
```
而在<a href="http://book.opensourceproject.org.cn/lamp/perl/perlcook2/index.html?page=opensource/0596003137_perlckbk2-chp-21-sect-4.html" target="_blank">perl cookbook</a>中的21.4节redirecting the browser中，则说明了perl模块的两种转向方法及其流程的不同：    
$r->header_out(Location => "http://www.example.com/somewhere");    
return REDIRECT;    
这个方法，是要把新url返回给browser，由browser端再发出DNS解析等一系列请求活动；    
$r->internal_redirect($new_partial_url);    
return OK;    
这个方法，是server自己内部重定向，虽然apache本身对这个请求依然要从头开始走一遍流程。而且这里的新url，只需要提供一个相对路径——唯一要注意的，是这个redirect之后不能再进行逻辑判断了，最好直接返回OK。    
    
    
