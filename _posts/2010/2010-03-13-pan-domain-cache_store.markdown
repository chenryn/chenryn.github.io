---
layout: post
title: nginx泛域名cache_store
date: 2010-03-13
category: nginx
---

回到nginx的cache_store方式上来。这是传统的nginx缓存方式，配置一般如下：
{% highlight nginx %}
upstream test{
    server 211.152.60.180:80;
}
server {
    listen       80;
    server_name  images6.static.com;
    location / {
        root /cache/images6.static.com/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_store on;
        proxy_store_access   user:rw  group:rw  all:r;
        proxy_temp_path     /cache/temp;
        if (!-f $request_filename) {
            proxy_pass http://test;
        }
    }
}
{% endhighlight %}
很简单明了。不过如果如果碰上img[1-16].static.com这样的客户，难不成把这一大段复制粘贴上16遍？汗~~必然得采用泛域名方式了。

server_name 支持.static.com的方式，root也支持/cache/$host/没有问题，save&amp;&amp;reconfigure，wget试一下，却没能缓存住。

于是去翻nginx官方wiki，刚巧看到proxy_store语法，除了on和off这两个想当然的赋值外，还有一个path！原文如下：

    Furthermore, the name of the path can be clearly assigned with the aid of the
    line with the variables:
    proxy_store   /data/www$original_uri;

赶紧换上，测试果然成功！conf如下：
{% highlight nginx %}
upstream test{
    server 211.152.60.180:80;
}
server {
    listen       80;
    server_name  .anjukestatic.com;
    location / {
        root /cache/$host/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_store /cache/$host$uri;
        proxy_store_access   user:rw  group:rw  all:r;
        proxy_temp_path      /cache/temp;
        if (!-f $request_filename) {
            proxy_pass http://test;
        }
    }
}
{% endhighlight %}
测试日志记录如下：

    1268456455.505 -/200 101 GET http://images6.static.com/property/20090911/600x600.jpg PARENT/211.152.60.180:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268456586.371 -/200 101 GET http://images6.static.com/property/20090911/600x600.jpg PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"
    1268456631.414 -/200 45 GET http://images9.static.com/property/20100103/420x315.jpg PARENT/211.152.60.180:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268456632.231 -/200 45 GET http://images9.static.com/property/20100103/420x315.jpg PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"

不知道为什么，这个$upstream_cache_status居然一直是-，郁闷一下下。

另，刚开始只写proxy_store /cache/$host;也不行，后来看error.log中提示

    “rename() "/cache/temp/0000000001" to "/cache/images6.static.com/" failed (20: Not a directory)”

才知道必须加上$uri。官方文档写的是$original_uri，日志里写的是$request_uri，nginx的内置变量有时候真的让人有些头晕……
思路跳回上篇的大小写，或许用下面这个办法可以？
{% highlight nginx %}
perl_set $url '
sub {
    my $r = shift;
    my $re = lc($r->uri);
    return $re;
}
';
proxy_store /cache/$host$url;
#proxy_cache_key $host$url$is_args$args;
{% endhighlight %}
未经试验，目前猜测，可能结果是nginx回源下载新文件，然后覆盖掉原来的——也就是说达到节省磁盘的目的，但HIT/MISS照旧。

