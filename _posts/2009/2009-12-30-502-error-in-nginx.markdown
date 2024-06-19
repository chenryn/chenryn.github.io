---
layout: post
theme:
  name: twitter
title: nginx502错误
date: 2009-12-30
category: nginx
---

NGINX 502 Bad Gateway错误是FastCGI有问题，造成NGINX 502错误的可能性比较多。将网上找到的一些和502 Bad Gateway错误有关的问题和排查方法列一下，先从FastCGI配置入手：

1. 查看FastCGI进程是否已经启动

NGINX 502错误的含义是sock、端口没被监听造成的。我们先检查fastcgi是否在运行

2. 检查系统Fastcgi进程运行情况

除了第一种情况，fastcgi进程数不够用、php执行时间长、或者是php-cgi进程死掉也可能造成nginx的502错误
运行以下命令判断是否接近FastCGI进程，如果fastcgi进程数接近配置文件中设置的数值，表明worker进程数设置太少
netstat -anpo | grep "php-cgi" | wc -l

3. FastCGI执行时间过长

根据实际情况调高以下参数值

fastcgi_connect_timeout 300;    
fastcgi_send_timeout 300;    
fastcgi_read_timeout 300;    

4. 头部太大

nginx和apache一样，有前端缓冲限制，可以调整缓冲参数

fastcgi_buffer_size 32k;
fastcgi_buffers 8 32k;

如果你使用的是nginx的负载均衡Proxying，调整

proxy_buffer_size  16k;
proxy_buffers 4 16k;

5. https转发配置错误

正确的配置方法
```nginx
server_name www.xok.la;
location /myproj/repos {
    set $fixed_destination $http_destination;
    if ( $http_destination ~* ^https(.*)$ ) {
        set $fixed_destination http$1;
    }
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Destination $fixed_destination;
    proxy_pass http://subversion_hosts;
}
```

