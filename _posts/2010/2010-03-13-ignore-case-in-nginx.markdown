---
layout: post
title: 忽略大小写（nginx）
date: 2010-03-13
category: nginx
---

刚才发现使用perl_set忽略大小写，完全不用perl_module和perl_require那么兴师动众，同样也能达到不错的效果。比如<a href="http://www.cnblogs.com/fengmk2/archive/2009/04/25.html" target="_blank">这个用perl做伪静态路径的例子</a>。随即就动手试验一下。

首先找一个windows的origin，因为windows是不区分大小写，这样可以确保任意wget都能返回200的结果；

然后按照上篇提到的方法配置nginx.conf（如下），stop&&start看看。
{% highlight nginx %}
upstream test{
    server 61.152.237.170:80;
}
perl_set $url '
    sub {
        my $r = shift;
        my $re = lc($r->uri);
        return $re;
    }
';
server {
    listen       80;
    server_name  www.hapi.com.cn;
    location / {
        root /cache/$host/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_store /cache/$host$url;
        proxy_store_access   user:rw  group:rw  all:r;
        proxy_temp_path      /cache/temp;
        if (!-f $request_filename) {
            proxy_pass http://test;
        }
    }
}
{% endhighlight %}
这里没法直接把lc($uri)继续set成$uri，应该是内置变量的缘故……

测试相关的access.log如下：

    1268461739.707 -/200 416073 GET http://www.hapi.com.cn/flash/age.swf PARENT/61.152.237.170:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268461767.366 -/200 416073 GET http://www.hapi.com.cn/flash/Age.swf PARENT/61.152.237.170:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268461785.360 -/200 416073 GET http://www.hapi.com.cn/flash/Age.swf PARENT/61.152.237.170:80 "-" "Wget/1.10.2 (Red Hat modified)"
    1268461806.195 -/200 416073 GET http://www.hapi.com.cn/flash/age.swf PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"

然后查看缓存目录：

[root@sdl4 /home/nginx/conf 14:36:46]# ls /cache/www.hapi.com.cn/flash/
age.swf

可以看到，只缓存了一个文件，但其他写法的请求就会反复重写……

看起来缓存空间确实是节省下来了，不过真正的缓存目的还是没达到。

再加上rewrite，变成下面这样：
{% highlight nginx %}
perl_set $url '
    sub {
        my $r = shift;
        my $re = lc($r->uri);
        return $re;
    }
';
server {
    listen       80;
    server_name  www.hapi.com.cn;
    if ($uri ~ [A-Z]){
    rewrite ^(.*)$ $url last;
    }
    location / {
        root /cache/$host/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_store /cache/$host$uri;
        proxy_store_access   user:rw  group:rw  all:r;
        proxy_temp_path      /cache/temp;
        if (!-f $request_filename) {
            proxy_pass http://test;
        }
    }
}
{% endhighlight %}
测试变可以了：

    1268469316.852 -/200 416073 GET http://www.hapi.com.cn/flash/agE.swf PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"
    1268469327.605 -/200 416073 GET http://www.hapi.com.cn/FLASH/age.swf PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"
    1268469397.312 -/200 416073 GET http://www.hapi.com.cn/FLASH/AGE.swf PARENT/- "-" "Wget/1.10.2 (Red Hat modified)"

另：因为uri改写后，是从location开始重新执行匹配等（相当于重新访问），所以这里proxy_store用$uri就行了——换句话说，前面那一大段都是白折腾。。。

