---
layout: post
title: squid问题-域名解析
date: 2009-11-03
category: squid
---

今天有老客户下单修改源IP地址1.2.3.4为1.2.3.7，一切正常操作过后进行测试，其中有台机器就是狂报404。
在用/home/squid/bin/squidclient -p 80 -m PURGE http://测试url
命令清除缓存，甚至重启dns/squid服务后，其测试访问的first-to-parent地址还是1.2.3.4！！

用dig检查确认内部DNS配置已经生效后，又检查了hosts文件也没有问题。

最后发现是squid.conf里的泛域名配置问题。

这批服务器在升级squid前，曾经在一台机器上测试新版本配置，之后一直没有更改，其中有如下字段：

```squid
cache_peer 1.2.3.4 parent 80 0 no-query no-netdb-exchange originserver
cache_peer_domain 1.2.3.4 www.test.com
```

所以在系统上怎么修改，都没法成功了。
由此可知，CDN加速对域名的解析，是squid配置文件最优先，然后才是系统的hosts文件，最后是DNS服务器。

