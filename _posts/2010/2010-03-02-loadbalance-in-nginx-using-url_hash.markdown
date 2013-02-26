---
layout: post
title: nginx负载均衡（url_hash）配置
date: 2010-03-02
category: nginx
---

nginx是著名的非专职全七层负载均衡器，在用惯了四层LVS后，终于碰上了麻烦：LVS后端的4台RS磁盘都较小（20G），跑不到一天就塞满了东西；而根据预估，实际上一天时间该节点也就只有20G的文件增长。很显然，因为lvs转发的轮询算法，导致RS重复缓存了相同的文件。

针对这个情况，可以有两个办法（我只想到两个，欢迎大家补充）：

1. 架构拆分，把不同的几个域名分别指向不同的server，这个在DNS上就能完成，不过就丧失了lvs的冗余；也可以用nginx的upstream+server配置，分别指向不通的RS，不过不同域名文件数量如果相差比较大的话，RS的负载就不均衡了……
2. url_hash，采用HAproxy的loadbalance uri或者nginx的upstream_hash模块，都可以做到针对url进行哈希算法式的负载均衡转发。

那么，就开始试试nginx的url_hash负载均衡吧：

1. 安装部署：
{% highlight bash %}
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.01.tar.gz
tar zxvf pcre-8.01.tar.gz
wget http://wiki.nginx.org/images/7/78/Nginx_upstream_hash-0.3.tar.gz
tar zxvf Nginx_upstream_hash-0.3.tar.gz
wget http://sysoev.ru/nginx/nginx-0.7.65.tar.gz
tar zxvf nginx-0.7.65.tar.gz
{% endhighlight %}
vi nginx-0.7.65/src/http/ngx_http_upstream.h
{% highlight c %}
struct ngx_http_upstream_srv_conf_s {
ngx_http_upstream_peer_t         peer;
void                           **srv_conf;

ngx_array_t                     *servers;  /* ngx_http_upstream_server_t */

+ngx_array_t                     *values;
+ngx_array_t                     *lengths;
+ngx_uint_t                       retries;

ngx_uint_t                       flags;
ngx_str_t                        host;
u_char                          *file_name;
ngx_uint_t                       line;
in_port_t                        port;
in_port_t                        default_port;
};
{% endhighlight %}

为了安全，可以修改一下nginx的version信息：vi nginx-0.7.65/src/core/nginx.h

{% highlight c %}
#define NGINX_VERSION      "2.6.STABLE21"
#define NGINX_VER          "squid/" NGINX_VERSION
{% endhighlight %}

vi nginx-0.7.65/src/http/ngx_http_header_filter_module.c

{% highlight c %}
static char ngx_http_server_string[] = "Server: squid/2.6.STABLE21" CRLF;
{% endhighlight %}

vi nginx-0.7.65/src/http/ngx_http_special_response.c

{% highlight c %}
static u_char ngx_http_error_tail[] =
"<hr><center>squid/2.6.STABLE21</center>" CRLF
"</body>" CRLF
"</html>" CRLF
{% endhighlight %}

{% highlight bash %}
cd pcre-8.01
./configure --prefix=/usr
make && make install
cd nginx-0.7.65
./configure --prefix=/home/nginx  --with-pcre --with-http_stub_status_module --with-http_ssl_module --without-http_rewrite_module --add-module=/tmp/nginx_upstream_hash-0.3
{% endhighlight %}
vi auto/cc/gcc

{% highlight c %}
# debug
#CFLAGS="$CFLAGS -g"
{% endhighlight %}

{% highlight bash %}
make && make install
{% endhighlight %}

这样就安装完成了。

2、配置文件

{% highlight nginx %}
upstream images6.static.com {
    server 11.11.11.11:80;
    server 11.11.21.12:80;
    server 11.11.21.13:80;
    server 11.11.21.14:80;
    hash    $request_uri;
}

server {
    listen       80;
    server_name  images6.static.com;
    access_log  /dev/null  main;
    location / {
        proxy_pass         http://images6.static.com;
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
{% endhighlight %}

以上配置的问题：

1. RS中不能设置nginx本机的其他端口，我本来设定的server 11.11.11.10:3128，希望能把nginx本机也开上squid，省出一台机器来。结果在确认配置了DNS的情况下，返回状态码全是503……
2. RS一旦有宕机的，nginx不会重算hash，导致部分url返回错误信息；而启用hash_again标签的话，其他RS就都乱了。
3. RS中默认logformat中将显示nginx的IP。

解决办法：
1. 不知道
2. 不采用hash_again标签而采用error_page重定向到专门的备份服务器保障访问
3. 修改RS的logformat，把%>a改成%{X-Real_IP}>h即可。

最后的根本性问题：

对nginx下的RS集群进行增减操作，是否会对hash表产生影响？nginx_upstream_hash目录中的CHANGES有如下三条：

    Changes with upstream_hash 0.3                                   06 Aug 2008
    *) Bugfix: infinite loop when retrying after a 404 and the "not_found" flag of *_next_upstream was set.
    *) Change: no more "hash_method" directive. Hash method is always CRC-32.
    *) Change: failover strategy is compatible with PECL Memcache.

nginx的wiki上，关于hash_again的doc这么写到：

    Number of times to rehash the value and choose a different server if the backend connection fails. Increase this number to provide high availability.

关于PECL Memcache，请参考下列链接：

<a title="http://www.surfchen.org/archives/348" href="http://www.surfchen.org/archives/348">http://www.surfchen.org/archives/348</a>
<a href="http://tech.idv2.com/2008/07/24/memcached-004/">http://tech.idv2.com/2008/07/24/memcached-004/</a>

尤其是第二个链接，其中关于rehash的解释，很好的解释了为什么大家都不推荐使用hash_again标签。
由此可知，upstream_hash模块，使用的是余数计算standard+CRC32方式，10+2的存活率是17%，3+1的存活率是23%！
而存活率最高的是consistent+CRC32方式，存活率是n/(n+m)*100%，10+2是83%，3+1是75%。

nginx的wiki中，还有另一个3rd模块upstream_consistent_hash，下回可以试试；
网上还有针对upstream_hash模块的补丁<a href="http://www.sanotes.net/wp-content/uploads/2009/06/nginx_upstream_hash.pdf">http://www.sanotes.net/wp-content/uploads/2009/06/nginx_upstream_hash.pdf</a>，好模块就是有人研究呀~~


