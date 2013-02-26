---
layout: post
title: 限速进阶
date: 2010-01-30
category: CDN
tags:
  - nginx
  - php
---

继续横向比较，之前有squid的限速配置，现在说nginx限速，nginx关于限速的模块有三个：HTTPLimitZoneModule、HTTPCoreModule和HTTPLimitReqModule，详见官方wiki，就不再贴链接了，能不能上天知道，真是地上芙蓉姐，天上绿坝娘呀……

# limit_zone配置
{% highlight nginx %}
http {
    limit_zone one $binary_remote_addr 10m; #每个clientIP定义一个10m大的session容器，根据32bytes/session，可以处理320000个session；
    server {
        location /download/ {
            limit_conn one 1;#限制一个IP并发连接数为1；
            limit_rate 300k;#限制每个连接数速率为300k；
        }
    }
}
{% endhighlight %}
目前网上的情况来看，zone方式的限速用的比较多，或许是较早的版本就支持这个模块吧。

# limit_req配置

{% highlight nginx %}
http {
    limit_req_zone $binary_remote_addr zone=one:10m rate=1r/s;#限制速率
    server {
        location /search/ {
            limit_req zone=one  burst=5;#限制并发处理数
        }
    }
}
{% endhighlight %}

这个模块是nginx0.7.22以后加上的，目前网上基本没什么实际说明，单就这个定义方式来看，感觉和之前的方式也没什么区别，a*b=c，一个定义a和b，一个定义b和c……
或许只能去wiki死磕英文才能搞清楚一点点吧~~

然后是lighttpd的限速：

lighttpd限速也是有两个方式，server.kbytes-per-second（对域名路径限制）和connection.kbytes-per-second（对单一连接限制），问题在于没有对并发连接数的限制（也就是上面我写的算式里的b）。而且是kbytes不是kbits，根据网友的说法，当期望限制在60Mb的时候，配置成：server.kbytes-per-second = 1800就差不多了……

# 限速配置
{% highlight lighttpd %}
connection.kbytes-per-second = 30 #单个连接不能超过30KB/s
$HTTP["host"] == "download.linuxfly.org" {
    server.name = "download.linuxfly.org"
    server.document-root = "/var/www/html/iso"
    accesslog.filename = "/var/log/lighttpd/iso-access.log"
    $HTTP["url"] =~ "^/download/" {
        dir-listing.activate = "enable"
        server.kbytes-per-second = 100 #/download路径下可用的最大是100KB/s
    }
    server.kbytes-per-second = 200 #除/download路径外，该域可用的最大带宽是200KB/s
}
{% endhighlight %}

最后，不要忘记lighttpd的单线程程序，还要受限于linux系统的单线程打开文件数限制。

lighttpd官方，还提供一个plugin方式，见http://redmine.lighttpd.net/projects/lighttpd/wiki/Docs:TrafficShaping。
这个需要在php代码中定制header来配合lighttpd。总的来说，lighttpd限速功能是不咋的……
{% highlight bash %}
#打补丁
wget http://redmine.lighttpd.net/attachments/697/mod_speed.c
mv mod_speed.c lighttpd_1.5/src/
cat >>Makefile.am
<<EOF
lib_LTLIBRARIES += mod_speed.la
mod_speed_la_SOURCES = mod_speed.c
mod_speed_la_LDFLAGS = -module -export-dynamic -avoid-version -no-undefined
mod_speed_la_LIBADD = $(common_libadd)
EOF
{% endhighlight %}
# plugin配置参数
{% highlight lighttpd %}
speed.just-copy-header = "enable"
speed.use-request = "enable"
{% endhighlight %}
//php定制header代码//
{% highlight php %}
<?php
header("X-LIGHTTPD-KBytes-per-second: 50");
header("X-Sendfile: /path/to/file");
?>
{% endhighlight %}


