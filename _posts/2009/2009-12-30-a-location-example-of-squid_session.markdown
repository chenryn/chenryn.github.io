---
layout: post
title: squid_session（首次访问跳转）
date: 2009-12-30
category: squid
---

上文perl例二中提到的第一次上某网站时先跳转公司主页。在CU上看到另一种办法。即在squid2.7以上版本中，有个squid_session。操作如下：
首先是安装：
安装squid ( for 2.7 stable )
修改源代码：vi src/errorpage.c 60行处将

"Generated %T by %h (%s)\n"

删除，让squid错误页面不产生服务器信息。
{% highlight bash %}
mkdir -p /usr/local/squid
./configure
configure options:  '--prefix=/usr/local/squid'
'--enable-storeio=diskd,ufs,aufs,null' '--enable-async-io=80'
'--enable-icmp' '--enable-removal-policies=heap,lru'
'--enable-useragent-log' '--enable-snmp' '--enable-referer-log'
'--enable-kill-parent-hack' '--enable-cache-digests'
'--enable-default-err-language=Simplify_Chinese'
'--enable-err-languages=Simplify_Chinese' '--enable-gnuregex'
'--enable-ipf-transparent' '--enable-pf-transparent'
'--enable-follow-x-forwarded-for' '--disable-wccp'
'--disable-delay-pools' '--disable-ident-lookups'
'--disable-arp-acl' '--with-large-files
make; make install; make clean
mkdir /usr/local/squid/helper
mkdir /usr/local/squid/che
cd hepler/external_acl/session; make
cp squid_session /usr/local/squid/helper
chmod 777 /usr/local/squid/che
chmod 777 /usr/local/squid/var
chmod 777 /usr/local/squid/var/logs
grep -v '^#' /etc/squid/squid.conf | sed -e '/^$/d' > /etc/squid/squid.conf.orig
mv /etc/squid.conf /etc/squid.conf.system
mv /etc/squid/squid.conf.orig /etc/squid/squid.conf
{% endhighlight %}
然后是squid.conf的修改：
{% highlight squid %}
external_acl_type session ttl=300 negative_ttl=0 children=1
concurrency=200 %SRC /usr/local/squid/helper/squid_session -t 900
//客户端第一个网页转向
acl session external session
acl all src all
acl manager proto cache_object
acl localhost src 127.0.0.1/32
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32
acl localnet src 10.0.0.0/8
# RFC1918 possible internal network
acl localnet src 172.16.0.0/12
# RFC1918 possible internal network
acl localnet src 192.168.0.0/16
# RFC1918 possible internal network
acl SSL_ports port 443
acl Safe_ports port 80
# http
acl Safe_ports port 21
# ftp
acl Safe_ports port 443
# https
acl Safe_ports port 70
# gopher
acl Safe_ports port 210
# wais
acl Safe_ports port 1025-65535
# unregistered ports
acl Safe_ports port 280
# http-mgmt
acl Safe_ports port 488
# gss-http
acl Safe_ports port 591
# filemaker
acl Safe_ports port 777
# multiling http
acl CONNECT method CONNECT
acl rangeget req_header Range .*
//定义多线程下载规则
http_access deny !session
//只有第一个执行才能打开
deny_info firstpage session
//deny_info指定的页面
http_access deny rangeget
//不允许多线程下载
http_access allow all
icp_access allow localnet
icp_access deny all
http_port 127.0.0.1:3128 transparent
http_port 192.168.101.1:3128 transparent
//绑定IP和端口，透明代理
http_port 192.168.188.1:3128 transparent
access_log /usr/local/squid/var/logs/access.log squid
//各种日志信息存放路径
cache_log /usr/local/squid/var/logs/cache.log
cache_store_log /usr/local/squid/var/logs/store.log
pid_filename /usr/local/squid/var/squid.pid
coredump_dir /usr/local/squid/var/coredump
cache_mem 100MB
//使用内存  总内存的一半
maximum_object_size_in_memory 40KB
//内存中对像大小
cache_swap_low 90
cache_swap_high 95
cache_dir aufs /usr/local/squid/che 500 16
256  //缓存目录
hierarchy_stoplist cgi-bin ?
acl QUERY urlpath_regex cgi-bin ?
cache deny QUERY
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|?) 0 0% 0
refresh_pattern . 0 20% 4320
acl shoutcast rep_header X-HTTP09-First-Line ^ICY.[0-9]
upgrade_http0.9 deny shoutcast
acl apache rep_header Server ^Apache
broken_vary_encoding allow apache
header_access Via deny all
header_access X-Cache deny all
//隐藏服务器信息
header_access X-Cache-Lookup deny all
header_access X-Forward-For deny all
via off
// 隐藏服务器信息
check_hostnames on
//检查主机名称
allow_underscore
//允许出现下划线
logfile_rotate 4
//rotate后保存日志数量
cache_mgr rainren_openbsd@yahoo.cn
visible_hostname rain
httpd_suppress_version_string on
// 隐藏服务器信息
{% endhighlight %}
最后创建ERR页，即squid.conf中的/usr/local/squid/share/errors/Simplify_Chinese/firstpage，如下：
{% highlight html %}
<meta http-equiv="refresh" content="10;url="http://www.google.com/">
<meta http-equiv="Content-Type" content="text/html;charset=gb2312" />
rainren
legend {
font-size:18px;
font-weight:bold;
color:black;
}
p {
font-size:16px;
color:#FF0000;
}
{% endhighlight %}
热诚欢迎您
怎么样？
好了，以上都是转载，还没试验过，不过有一个我知道的，就是不用修改ERR页，在deny_info里，可以直接写http://www.google.com。


