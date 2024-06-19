---
layout: post
theme:
  name: twitter
title: 加强了解nginx的几个问题
category: nginx
---
被问到一些关于nginx或者说nginx运维相关的问题，记录下来几个值得思考的。这里面有些是自己曾经想到过但是浅浅的了解下就不放在心上的，有些是根本没想过这会成为一个"有意思"的问题的......

## 1、nginx日志记录得到client的IP原理。

nginx记录的client的IP分两种，一种是$remote_addr，一种是$http_x_forwarded_for。其中X-Forwarded-For里存放的是proxy加入的client端IP，通过http header传递的。而$remote_addr是TCP上的结果。但是具体如何不知道。今天回来翻nginx的src，先从定义nginx变量的ngx_http_variable.c看到$remote_addr是这样来的:

```c
ngx_http_variable_remote_addr(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data)
{
    v->len = r->connection->addr_text.len;
    v->valid = 1;
    v->no_cacheable = 0;
    v->not_found = 0;
    v->data = r->connection->addr_text.data;

    return NGX_OK;
}
```

然后可以在ngx_http.h和ngx_http_request.h里看到

```c
typedef struct ngx_http_request_s     ngx_http_request_t;
...
struct ngx_http_request_s {
    uint32_t                          signature;         /* "HTTP" */
    ngx_connection_t                 *connection;
    ngx_buf_t                        *header_in;
    ngx_http_headers_in_t             headers_in;
    ngx_http_headers_out_t            headers_out;
    ngx_http_request_body_t          *request_body;
...
}
```

然后在ngx_connection.c里看到

```c
#include <ngx_core.h>
...
ngx_listening_t *
ngx_create_listening(ngx_conf_t *cf, void *sockaddr, socklen_t socklen)
{
    ngx_listening_t  *ls;
    struct sockaddr  *sa;
    u_char            text[NGX_SOCKADDR_STRLEN];

    ls = ngx_array_push(&cf->cycle->listening);
    ngx_memzero(ls, sizeof(ngx_listening_t));
    sa = ngx_palloc(cf->pool, socklen);
    ngx_memcpy(sa, sockaddr, socklen);
    ls->sockaddr = sa;
    len = ngx_sock_ntop(sa, text, NGX_SOCKADDR_STRLEN, 1);
    ls->addr_text.data = ngx_pnalloc(cf->pool, len);
    ngx_memcpy(ls->addr_text.data, text, len);
...
};
```

在ngx_core.h中，加载了

```c
#include <ngx_socket.h>
```

所以结果就是说，nginx日志里记载的$remote_addr变量，就是由connection的socket里获得的。在socket.h里可以看到accept函数的定义：

```c
int accept(int sockfd, void *addr, int *addrlen);
```

另外，nginx上除了$remote_addr变量外，还有一个$binary_remote_addr变量。而且在ngx_http_variables.c里，根据是否是IPv6协议，做了区分，最终地址是通过r->connection结构体里的sockaddr->sin_addr获得。

目前就看到这里了......关于socket如何从监听套接字上获得IP并建立连接套接字的，以后再继续研究TCP层上的知识。

## 2、cookie insert原理在负载均衡上是如何实现的。

作7层负载均衡的时候，会遇到cookie类型的会话保持。

一般的session保持办法，是利用源地址哈希(source-hash)的办法，把同一个来源客户(实际通常是同一个C段的IP)，固定指向后端的同一台机器。

而利用cookie的办法，则是在负载均衡器上，给响应客户请求的http-response-header里Set-Cookie字段添加上有关内容，然后根据客户请求的http-request-header里Cookie的该字段内容，分发到和之前一样的后端服务器上。

在nginx上没有标准模块完成这个事情，不过可以用[map功能](http://wiki.nginx.org/HttpMapModule)进行简单的模拟，如下：

```nginx
    map $COOKIE_route $group {  
         700003508     admin;  
         ~*3$     admin;  
         default   user;  
     }  
      
     upstream backend_user {  
         server   10.3.24.11:8080;  
     }  
      
     upstream backend_admin {  
         server   10.3.25.21:8081;  
     }  
      
     server {  
         listen       80;  
         server_name  photo.domain.com;  
      
         location / {  
             proxy_pass            http://backend_$group;  
         }  
     }  
```

不过nginx社区有第三方模块叫做"nginx-sticky-module"的，用来完成这个功能。项目托管在googlecode上，具体地址是<http://code.google.com/p/nginx-sticky-module>。具体实现的效果是首先根据轮训RR随机到某台后端，然后在响应的Set-Cookie上加上route=md5(upstream)字段，第二次请求再处理的时候，发现有route字段，直接导向原来的那台服务器。

编译后启用配置如下：

```nginx
upstream {
  sticky [name=route] [domain=.domain.com] [path=/] [expires=1h] [hash=index|md5|sha1] [no_fallback];
  server 127.0.0.1:9000;
  server 127.0.0.1:9001;
  server 127.0.0.1:9002;
}
```

## 3、nginx是多worker的，但是80端口只能有一个占用，这一段的工作原理是怎样的？

这个问题的回答其实在第一个问题上已经部分涉及到了。就是socket的两个分类，一个是监听套接字，一个是连接套接字。占用80端口的，是使用的监听套接字。而worker里使用的，是accept之后建立的连接套接字。

正常情况下，nginx对worker加锁，在每一时刻，只有一个worker获得accept的权力。当监听的socket可以accept的时候，即有新链接时，主进程通过epoll的方式处理，先把这个事件保存起来，等通过锁的竞争选取一个worker后，再由这个worker真正的执行accept创建连接套接字，然后主进程返回监听状态。

代码中主要是ngx_trylock_accept_mutex()函数和ngx_process_events_and_timers()函数等，不过这个看不太懂，更多是根据别人的描述文章了。

## 4、一致性哈希的原理。

在7层负载均衡的时候，经常会利用到哈希。关于nginx上的url_hash和consistent_hash模块，我在2年前曾经简单的看过，博文链接如下：

1. [url_hash的perl脚本模拟](http://chenlinux.com/2010/03/15/consistent_hash/)
2. [consistent_hash的perl脚本模拟](http://chenlinux.com/2010/03/16/implement-consistent_hash-by-perl/)

两年后回头来看当初的脚本，真是很烂。不过从关键的uri和peer都取CRC32和取值做减法还是可以看出来一致性哈希的原理，即将节点通过哈希取值后均匀分布在一个0-9999999999的'圆环'上。然后要存储的url同样的算法取哈希值后，放进这个"圆环"里，顺时针方向离他最近的那个节点，即为他实际存储的节点。

在CPAN上，其实有[Set::ConsistentHash](http://search.cpan.org/~bradfitz/Set-ConsistentHash-0.92/lib/Set/ConsistentHash.pm)模块可以看。如果是简单运用的话，[Hash::ConsistentHash](http://search.cpan.org/~karavelov/Hash-ConsistentHash-0.05/lib/Hash/ConsistentHash.pm)模块是基于Set::ConsistentHash模块封装的易用版本。示例如下：

```perl
use Hash::ConsistentHash;
use String::CRC32;
my $chash = Hash::ConsistentHash->new( buckets => {A=>1, B=>2, C=>1},
                                       hash_func=>\&crc32,
                                     );
my $server = $chash->get_bucket('foo');
```

## 5、inotify丢事件。

这个问题没有碰到过，只在网上看到过一篇[Linux事件监控机制遗漏事件问题的相关分析](http://doc.chinaunix.net/linux/201007/687123.shtml)，里面提到"发现在过于频繁的往目录下添加文件和目录的时候,会丢事件"。但是只提到了这么个问题，然后通过重复添加监听解决问题，没有提到原因。

我个人疑心，会不会是sysctl参数没有设置好的原因呢？

sysctl里关于inotify的参数有三个，如下：

```bash
[root@localhost ~]$ sudo /sbin/sysctl -a|grep inotify
fs.inotify.max_queued_events = 16384
fs.inotify.max_user_watches = 8192
fs.inotify.max_user_instances = 128
```

上示是默认值，明显偏小。比方sersync2方案中，启动前就要求修改这些值到50000000。如果启动的时候在sysctl范围内，启动时没问题的，但是迅速的添加到了范围外，那么应该就会出这个问题了。

当然，以上是我个人猜测，也说不准真的是inotify本身却有问题。

## 7、nginx的worker是怎么绑定到cpu上的？

nginx有一个配置，就是启动多个worker的时候，可以使用cpu_affinity配置将worker分别绑定在不同的cpu上。

如果有8个cpu，那么相应参数就是：

  00000001 00000010 00000100 00001000 00010000 00100000 01000000 10000000

也就是类似占位符一样一个位置代表一个CPU。如果按照普通理解的二进制，那么0011不是第三个CPU而是绑定在第1和第2个CPU上平均……

这种写法，是由操作系统决定的。在nginx的ngx_process_cycle.c中，相关内容如下：

```c
#include <ngx_config.h>

static void
ngx_worker_process_init(ngx_cycle_t *cycle, ngx_uint_t priority)
{
...
    if (cpu_affinity) {
        if (sched_setaffinity(0, 32, (cpu_set_t *) &cpu_affinity) == -1) {
            ...
        }
    }
}
```

在ngx_config.h中:

```c
#elif (NGX_LINUX)
#include <ngx_linux_config.h>
```

在ngx_linux_config.h中:

```c
#include <sched.h>
```

其实可以直接通过man sched_setaffinity看说明：

```c
       #include <sched.h>
       int sched_setaffinity(pid_t pid, unsigned int cpusetsize,
                             cpu_set_t *mask);
```

关于这个*mask，man文档之后描述如下：

       The  actual  system
       call  interface is slightly different, with the mask being typed as unsigned long *, reflecting
       that the fact that the underlying implementation of CPU sets is a simple bitmask.

bitmask就是上面说到的那个意思了~~

## 8、某应用经过7层负载均衡访问应用服务器，因业务需要设置了5秒无响应即返回502错误。有反馈说全网范围内5%的访问出现错误，如何判断问题具体出在哪里？

这个问题目前我还想不到有什么特别简捷的办法。靠类似nagios那样的定时监测，肯定是很不容易抓到错误的。如果靠debug日志或者strace命令啊，tcpdump命令啊的，在高流量的情况下，又太容易淹没在海量的正常数据里了。

另一个猜测是连接数满了，TCP的或者HTTP的。不过按理说负载均衡器上应该有监控，不至于到这么危急的时候还是通过客户端访问来反馈问题......

