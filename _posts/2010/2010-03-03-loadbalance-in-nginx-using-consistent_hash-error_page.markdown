---
layout: post
title: nginx负载均衡（consistent_hash、error_page）进阶
date: 2010-03-03
category: nginx
---

话接上篇，采用consistent方式进行url_hash负载均衡。

重新编译nginx过程如下：

{% highlight bash %}
wget http://download.github.com/replay-ngx_http_consistent_hash-77b6940.tar.gz
tar zxvf replay-ngx_http_consistent_hash-77b6940.tar.gz
cd nginx-0.7.65
./configure --prefix=/home/nginx   --with-pcre=/tmp/pcre-8.01 --with-http_stub_status_module --with-http_ssl_module --without-http_rewrite_module --add-module=/tmp/nginx_upstream_hash-0.3 --add-module=/tmp/replay-ngx_http_consistent_hash-77b6940
make && make install
{% endhighlight %}

完成。配置文件修改如下：

{% highlight nginx %}
upstream images6.static.com {
    server 11.11.11.12:80;
    server 11.11.11.13:80;
    consistent_hash $request_uri;
}
{% endhighlight %}

访问测试正常。

error_page配置备份如下：

{% highlight nginx %}
upstream backup {
    server 11.11.11.14:80;
}

error_page 404 500 502 503 504 =200 @fetch;
location @fetch {
    proxy_pass        http://backup;
    proxy_set_header   Host             $host;
    proxy_set_header   X-Real-IP        $remote_addr;
    proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
}
{% endhighlight %}

注意：=200里的等号，左边有空格，右边没空格。


