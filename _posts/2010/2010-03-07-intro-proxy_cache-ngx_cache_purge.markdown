---
layout: post
title: nginx的proxy_cache和cache_purge模块试用记录
date: 2010-03-07
category: nginx
---

nginx的类squid哈希式cache功能，据张宴说是基本稳定可用了，昨天找个机会和时间，试着测用了一把，把要点记录一下：

首先是编译nginx，方便起见，把一些心仪的模块统统加上了，version如下：

    built by gcc 4.1.2 20080704 (Red Hat 4.1.2-44)
    TLS SNI support disabled
    configure arguments: --prefix=/home/nginx --with-pcre --add-module=../ngx_http_consistent_hash --add-module=../ngx_max_connections --add-module=../ngx_cache_purge --add-module=../ngx_mp4_streaming_public --with-cc-opt=-O3 --with-http_stub_status_module --with-http_ssl_module --with-http_flv_module --without-http_memcached_module --without-http_fastcgi_module --with-google_perftools_module

编译过程中几个注意事项：

1. 必须采用--with-pcre，而不要偷懒采用--without-http_rewrite_module，否则配置文件里将不支持if判断；
2. 加载mp4_streaming，必须采用--with-cc-opt=-O3方式进行编译。
3. max_connections模块默认支持nginx最新版本是0.8.32，需要vi修改其DIR，然后path -p0，但千万不要看见有个Makefile就执行make && make install了，因为它会毫无道理的把整个nginx安装到当前目录的.nginx下隐藏起来……

话说我add这个max_connections模块能怎么用自己也没想好，反正官方有limit_zone和limit_req限制client，再add个限制nginx2oringin的也不在乎吧……汗~~

比较囧的一点是，经过我折腾的nginx，虽然去除了debug -g模式编译，还是有4M多大……

sina的ncache模块，在我下载的最新的nginx0.8.34src上无法使用，而且ncache作者介绍说ncache的缓存不用内存，且其purge方式为标记为过期但并不更改文件内容直到下次访问请求以节省磁盘IO的负担；但根据我的试验，nginx的cache_purge模块则是采用了删除过期文件的方式进行（当然，proxy_cache的过期还是标记而不删除的，不然太耗IO了……）。

然后贴一下，实验完成后的配置文件：
{% highlight nginx %}
user nobody nobody;
worker_processes 1;
google_perftools_profiles /tmp/tcmalloc;
worker_rlimit_nofile 65535;

events
{
    use epoll;
    worker_connections 65535;
}

http
{
    include       mime.types;
    default_type  application/octet-stream;
    
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log  logs/access.log  main ;
    
    #  charset  utf-8;
    
    server_names_hash_bucket_size 128;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size 300m;
    
    sendfile on;
    tcp_nopush     on;
    
    keepalive_timeout 60;
    
    tcp_nodelay on;
    
    client_body_buffer_size  512k;
    proxy_connect_timeout    5;
    proxy_read_timeout       60;
    proxy_send_timeout       5;
    proxy_buffer_size        16k;
    proxy_buffers            4 64k;
    proxy_busy_buffers_size 128k;
    proxy_temp_file_write_size 128k;
    
    gzip on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 2;
    gzip_types       text/plain application/x-javascript text/css application/xml;
    gzip_vary on;
    #定义cache临时缓存路径，必须和哈希缓存路径在同一个磁盘上
    proxy_temp_path   /cache/proxy_temp_dir;
    #定义cache哈希缓存路径，目录层次，缓存名称及所允许缓存的最大文件大小，未被访问文件多久自动清除，缓存最多使用多大磁盘
    proxy_cache_path  /cache/proxy_cache_dir  levels=1:2   keys_zone=cache_one:200m inactive=1d max_size=30g;
    #后端源站地址
    upstream backend{
        server 10.10.10.13:80;
    }
    
    server
    {
        listen       80;
        server_name  www.test.com;
        #这里就是关键部分了，定义哈希缓存及缓存过期；
        #因为nginx提供的过期控制是针对http_status_code的，我本想通过location中限定类型的方法完成曲线救国，结果发现：一旦location中限定了文件类型，缓存过期的定义就失效！！
        #也就是说，限定文件类型后的哈希缓存，是绝绝对对的强制永久缓存——不单过期失效，下面的purge也失效——或许换一个场景，这个刚好有用。
        #   location ~* .*.(css|gif|jpg|png|html|swf|flv)
        location / {
        #启用flv拖动功能；
            flv;
            #这里定义是如果碰上502、504、timeout和invalid_header等情况，自动调向下一个oringin继续请求，这个有时候有用，有时候可能被攻击的会很惨……
            proxy_next_upstream http_502 http_504 error timeout invalid_header;
            #使用上面定义的具体某个缓存；
            proxy_cache cache_one;
            #200和304的状态码访问都缓存1天；
            proxy_cache_valid  200 304 1d;
            #由主机名、唯一资源定位符、参数判断符和请求参数共同生成哈希缓存的key
            proxy_cache_key $host$uri$is_args$args;
            #下面几个是常见的nginx透明代理header
            proxy_pass_header User-Agent;
            proxy_set_header Host  $host;
            proxy_set_header X-Forwarded-For  $remote_addr;
            #下面是为了证明给大家看他确实能缓存，增加的两句话；如果真想要看到HIT和MISS的话，可以addnginx的另一个模块slowfs_cache，配置上和官方的proxy_cache极其相似，不过自带有变量$slowfs_cache_status，可以显示HIT/MISS/EXPIRED。
            add_header X-Cache "HIT from cache_test";
            add_header Age "1";
            proxy_pass http://backend;
        }
        #下面这段就是add的purge_mod，只要在url的^/前再加上/purge，就会自动被理解成PURGE请求，刷新成功返回200的特定页面，失败返回404的普通错误页面。
        #这个proxy_cache_purge格式没法改变，我本想改成if ($request_method = PUREG){…}试试，结果发现它不认……
        location ~ /purge(/.*){
            allow            127.0.0.1;
            allow            211.151.67.0/24;
            deny            all;
            proxy_cache_purge    cache_one   $host$1$is_args$args;
        }
        #不区分大小写匹配~*，网上流传很广的写法*~*是错滴；而且能匹配不代表保存同一份缓存；
        #这部分定义不缓存而是透传的请求类型。介于无法通过类型来控制缓存，那么这里不缓存的控制就必须确保严格正确了……
        #可是bug来了，当我写成swf?$的时候，swf/swf?/swf?*都不缓存；写成swf?的时候，又变成都缓存——nginx压根就分不清！
        location ~* .*.(swf|asp)?{
            proxy_pass_header User-Agent;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarder-For $remote_addr;
            add_header X-Cache "MISS from cache_test";
            proxy_pass http://backend;
        }
    }
}
{% endhighlight %}
配置完成。测试如下：
wget http://www.test.com/List/j.Html -S -O /dev/null -e http_proxy=127.0.0.1
    --13:17:48--  http://www.test.com/List/j.Html
    Connecting to 127.0.0.1:80... connected.
    Proxy request sent, awaiting response...
    HTTP/1.1 200 OK
    Server: squid/2.6.STABLE21
    Date: Sun, 07 Mar 2010 05:17:48 GMT
    Content-Type: text/html; charset=utf-8
    Connection: close
    Vary: Accept-Encoding
    Content-Length: 25126
    Last-Modified: Wed, 10 Feb 2010 09:38:26 GMT
    ETag: "948acecb34aaca1:6647"
    X-Powered-By: ASP.NET
    X-Cache: HIT from cache_test
    Age: 1
    Accept-Ranges: bytes
    Length: 25126 (25K) [text/html]
    Saving to: `/dev/null'
    
    100%[====================================================================================================================>] 25,126      --.-K/s   in 0s

13:17:48 (521 MB/s) - `/dev/null' saved [25126/25126]

[root@sdl4 ~ 13:17:48]#
wget -S -O /dev/null -e http_proxy=127.0.0.1 "http://www.test.com/Search.ASP?KeyWord=整形视频"
    --13:17:50--  http://www.test.com/Search.ASP?KeyWord=%D5%FB%D0%CE%CA%D3%C6%B5
    Connecting to 127.0.0.1:80... connected.
    Proxy request sent, awaiting response...
    HTTP/1.1 200 OK
    Server: squid/2.6.STABLE21
    Date: Sun, 07 Mar 2010 05:17:51 GMT
    Content-Type: text/html; charset=utf-8
    Connection: close
    Vary: Accept-Encoding
    X-Powered-By: ASP.NET
    Content-Length: 24987
    Set-Cookie: ASPSESSIONIDSSQQSBST=KDPDLODBNLGONONBNHCJCEGP; path=/
    Cache-control: private
    X-Cache: MISS from cache_test
    Length: 24987 (24K) [text/html]
    Saving to: `/dev/null'
    
    100%[====================================================================================================================>] 24,987      25.6K/s   in 1.0s
    
    13:17:52 (25.6 KB/s) - `/dev/null' saved [24987/24987]
完成。
至于？的问题，目前针对需要，倒有另一个办法：
在location / {}中，根据请求参数判断进行传递。即写成如下：
{% highlight nginx %}
location / {
    ……
    if ($is_args){
        add_header X-Cache "MISS from cache_test";
        proxy_pass http://backend;
    }
}
location ~* .*\.asp{
    proxy_pass_header User-Agent;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarder-For $remote_addr;
    add_header X-Cache "MISS from cache_test";
    proxy_pass http://backend;
}
{% endhighlight %}
不过依然有问题：

1. nginx的if不支持&amp;&amp;或者||，万一有些类型（比如htm和jpg）又要求带？的也缓存，显然又和这个$is_args冲突；
或许采用下面的办法能继续区分？（未试验）
{% highlight nginx %}
set $yn $is_args;
if ($uri ~* .(htm|jpg)){
    set $yn "";
}
if ($yn){
    proxy_pass http://backend;
}
{% endhighlight %}
；
2. nginx的if中不单不支持proxy_cache，居然也不支持proxy_set_header等定义，只能单纯的proxy_pass。


