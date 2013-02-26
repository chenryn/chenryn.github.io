---
layout: post
title: squid & gzip
date: 2009-12-30
category: squid
---

标题很简单，内容很复杂，而且我也用不上。姑且存档吧：
原标题《VIGOS eCAP GZIP Adapter for SQUID Proxy Cache》
第一句话就让我很绝望，本插件只适用于squid3.1及以上版本——squid有比3.1更高的版本么——前文提到的有session控制的squid2.7我都还没看呢~哭

办法：
{% highlight bash %}
wget http://www.measurement-factory.com/tmp/ecap/libecap-0.0.2.tar.gz
wget http://www.vigos.com/products/eCAP/vigos-ecap-gzip-adapter-1.1.0.tar.gz
wget http://www.squid-cache.org/Versions/v3/3.1/squid-3.1.0.9.tar.gz
tar xvfz squid-3.1.0.9.tar.gz
tar xvfz libecap-0.0.2.tar.gz
tar xvfz vigos-ecap-gzip-adapter-1.1.0.tar.gz
cd libecap-0.0.2/
./configure
make
make install
cd ../vigos-ecap-gzip-adapter-1.1.0/
./configure
make
make install
cd ../squid-3.1.0.9/
./configure --enable-ecap
make
make install
cat >> etc/squid.conf
<<EOF
ecap_enable on
ecap_service gzip_service respmod_precache 0
ecap://www.vigos.com/ecap_gzip
loadable_modules /usr/local/lib/ecap_adapter_gzip.so
acl GZIP_HTTP_STATUS http_status 200
adaptation_access gzip_service allow GZIP_HTTP_STATUS
EOF
{% endhighlight %}
以上，3.1毕竟还是测试版，这个留待以后吧~~

另，据《squid中文权威指南》作者潘勇华的blog说，这个“基于squid3.1的eCAP接口的流量压缩适配器”，对被自己压缩过的内容，简单的把Etag删除。


