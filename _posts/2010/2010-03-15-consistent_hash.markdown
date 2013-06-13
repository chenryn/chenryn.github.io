---
layout: post
title: 一致性哈希研究
date: 2010-03-15
category: web
tags:
  - nginx
  - perl
---

今天继续看nginx的consistent_hash_module，因为想可能的话可以把url和对应的peer关系查出来，形成一个类似squidclient一样的方式。以下内容都是我从百度、谷歌、nginx模块应用指南和ngx_upstream_consistent_hash_module的src中自我理解得出的，欢迎指正。

## 一、url_hash的原理

在一些稳定的系统（即不考虑流量变化导致时常add/del服务器）中，采用upstream_url_hash+固定的peer+一个backup的方式应该很不错。整个module很“简单”，对$uri进行CRC32计算得到key，然后把key针对peer的总数求余数，余几就把$uri存在第几个peer上。over~~

用perl表示，大概如下吧：

{% highlight perl %}
#!/usr/bin/perl -w
use String::CRC32;
my ($url, $sum) = @ARGV;
my $crc = crc32("$url");
my $num = $crc % $sum;
printf "%s cached at the %s peer by the key %s\n", $url, $num, $crc;
{% endhighlight %}

测试如下：

{% highlight bash %}
[root@sdl4 /home/rao 21:41:47]# ./crc.pl http://www.baidu.com 10
http://www.baidu.com cached at the 4 peer by the key 3500265894
{% endhighlight %}

## 二、consistent_hash的原理

1. consistent_hash在url_hash的基础上进一步，不单单对$uri进行CRC32计算，同样对peer进行CRC32计算。然后向下寻找离crc32($uri)最近的一个crc32($peer)，并把$uri存在这个peer上。
2. 单纯进行uri和peer的crc32并寻找最近点的话，在均衡方面做到并不好，因为事实上sum(peer)不大可能大到满足理论推测的，就这么五六台peer，肯定很容易就出现个别服务器爆满的情况，所以consistent_hash还有进阶做法，为真实的peer做虚拟节点，然后uri寻找最近的虚拟节点存储（当然实际上还是对应到真实peer了）。按照前人实验，如果10台peer的话，给每个peer分成100-200个虚拟节点，才能比较完美的达到url_balance。

## 三、ngx_upstream_hash_module的原理

nginx模块应用指南网上到处有，这里只贴CU论坛上关于upstream的一段翻译<http://bbs.chinaunix.net/thread-1479873-1-1.html>，大概说明的代码流程就是

1. ngx_http_upstream_hash注册upstream初始化函数并填充CONF信息，即读取nginx.conf中upstream backend {}中的内容；
2. ngx_http_upstream_init_hash初始化函数，（如果peer不是IP是Domain的话）DNS resolv，（根据peer的数量、端口、权重等）allocate sockets；
3. ngx_http_upstream_peer_data_t初始化peer函数，计算hash，设置get、free、tries变量；
4. ngx_http_upstream_get_peer(ngx_peer_connection_t *pc, void *data)，接受1中得到的peer列表，进行%运算，返回peer_name，告知nginx建立连接；
5. ngx_http_upstream_free_peer(ngx_peer_connection_t *pc, void *data, ngx_uint_t state)，完成rehash。

## 四、ngx_consistent_hash_module的原理

这个module是在upstream的架构上完成的，所以对照上面的指南，倒是可以看出来一点点头绪。

1. 在计算crc32的时候，不单单是使用uri和server_name:port的字符串，而且还增补上了字符串length;
2. 和url_hash禁止给server加其他任何配置不同，src中也有weight的相关定义（0-255）处理（计算虚拟节点时），以完成weight->hash_cyc的映射；具体算法如下，MMC_CONSISTENT_POINTS，最开始定义了它等于160.应该就是全默认状态下的虚拟节点，naddrs或许是当前server的排序序号？（未知）

{% highlight c %}
points += server[i].weight * server[i].naddrs * MMC_CONSISTENT_POINTS;
{% endhighlight %}

3. ngx_http_upstream_consistent_hash_find(ngx_http_upstream_consistent_hash_continuum *continuum, ngx_uint_t point)函数test middle point，用来计算url的crc32离哪个point最近。
4. 使用了ngx_crc32_long来计算hash，这部分在nginx/src/core/ngx_crc32.c中。看到里头提供了256的初始化数据，和perl的String::CRC32里的是一样的……
