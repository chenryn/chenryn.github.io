---
layout: post
theme:
  name: twitter
title: 用systemtap定位nginx1.2在header解析时的报错
category: monitor
tags:
  - nginx
  - systemtap
---
一个url请求，在经过代理层访问应用层后，会报502错误。检查发现应用层是Nginx0.7.64+Resin3的结构，代理层是Nginx1.2。直接访问Nginx0.7.64是没问题的，访问Nginx1.2就会返回"upstream sent invalid header while reading response header from upstream"。

首先简单的通过编译--with-debug的nginx然后配置error_log debug;可以看到，nginx是在处理完Expires头后失败的。但是无法具体显示下一个头是在哪个地方。

所以进nginx/src/http/modules/ngx_http_proxy_module.c里，找到ngx_http_proxy_process_header函数，其中是根据ngx_http_parse_header_line函数的结果做判断的。所以出去看nginx/src/http/ngx_http_parse.c里ngx_http_parse_header_line函数，结果发现，从nginx1.0.14开始，新增加了关于空的判断：
```c
if (ch == '\0') {
                    return NGX_HTTP_PARSE_INVALID_HEADER;
                }
```
变更记录：<http://trac.nginx.org/nginx/browser/nginx/tags/release-1.0.14/src/http>

说明如下：


    *) Headers with null character are now rejected.

        Headers with NUL character aren't allowed by HTTP standard and may cause
        various security problems. They are now unconditionally rejected.

但是这个NULL出现在哪里呢？这里就要用systemtap来查了～

安装不说了，直接yum或者apt-get都有。

介绍的话，有余锋大神的一系列slide。然后有官网的文档。另外发现了这个翻译beginner的[中文文档](http://blog.csdn.net/kafeiflynn/article/details/6429976)。

最后在本例里的简单使用了：

首先要自己启动/usr/local/nginx/sbin/nginx程序；

然后运行systemtap命令：
```bash
stap -e 'probe process("/usr/local/nginx/sbin/nginx").statement("ngx_http_parse_header_line@src/http/ngx_http_parse.c:855"){printf("%s\n",$$locals$$);}'
```

最后发起出错的请求。查看stap的输出。类似下面这样：

    c='u' ch='U' p="ser-Agent: curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5^M
    Host: www.connect.renren.com^M
    Pragma: no-cache^M
    Accept: */*^M
    Proxy-Connection: Keep-Alive^M
    ^M
    e" hash=117 i=117 state=1 lowcase=""

说明：

* probe设探针    
* process运行命令    
* function指定函数    
* statement指定代码位置    
* $$vars变量    
* $$locals内部变量    
* $$parms参数变量    

上面三个变量后面加\$显示具体内容或者成员

可以先printf("%s\n",\$\$locals)看到显示的是p的内存地址，每次\+\+。然后\$\$locals\$看具体内容。

最终观察到，在header中某行处理到第N个字节的时候，不再输出，即在该字节处碰到了NULL。
