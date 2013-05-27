---
layout: post
title: squid请求处理流程（源站故障转向研究）
date: 2009-12-31
category: squid
---

今天继续想别的办法，第一，当然还是修改源代码，这个C++可惜俺不懂，只是大略的通过百大哥谷大婶知道了squid的请求处理流程：

1. 客户端和squid建立连接（client-side模块、clientBeginRequest()函数）；
2. 检查ACL访问控制；
3. 检查重定向；
4. 检查缓存命中（GetMoreData()函数），写入StoreEntry（client-side模块）；
4.1. 命中（client-side模块）；
4.2. 未命中（rotoDispatch()函数启动peer算法，算法检查never|always_direct）；
5. 收到ICP响应，选择中止，转发请求（protoStart()函数）；
6. 打开到源站或peer的连接（HTTP模块），发起请求（NetworkCommunication模块），建立连接并处理异常（comm.c程序）；
7. 建立写缓存（HTTP模块），将请求写入socket；
8. 建立相应的socket读缓存，接受处理HTTP响应（即，如果已有socket，可以跳过6、7步）；
9. 响应被接受，squid接收到header信息，并在被读取时把data追加进StoreEntry，同时通知client-side模块，这个过程的速度取决于delay_pools；
10. client-side模块从StoreEntry取数据，并写入客户端socket；
11. 客户端读取完成，数据根据情况（refresh、cache）存入磁盘；
12. 回源取完数据，标记StoreEntry为“完成”（client-side模块），socket关闭或保留到持久连接池；
13. 数据写入客户端socket完成，从StoreEntry注释掉client-side模块，同样，关闭或等待客户端连接请求。

原先的想法就是在第3步，而缓存在第4步，所以不行。也就是说，必须在第4步以后操作，才能不影响CDN的命中率。很显然，我注意到一个词，第6步中“建立链接并处理异常”的comm.c程序；其次，第9步“响应被接受”，也就是说，可能建立链接但没响应，这里就应该是socket的存活过期时间来决定。<br />

思路到此为止，往下就是编程开发能力的事儿了，哭ing~~

第二个办法，还在squid本身上做文章。我注意到，处理流程的4.2步上，squid是同时检查源站和cache_peer的。那么，在源站故障的时候，cache_peer可以设成其他服务器顶上。这样的情况，不单解决一个url跳转，还能做一个源站备份。配置如下：

{% highlight squid %}
nonhierarchical_direct off
prefer_direct on
cache_peer 192.168.1.1 parent 80 0 no-query originserver name=S1
cache_peer 192.168.1.2 parent 80 0 no-query name=S2
cache_peer 192.168.1.3 parent 80 0 no-query name=S3
acl myservice dstdomain .site.com
cache_peer_access S1 allow myservice
cache_peer_access S2 allow myservice
cache_peer_access S3 allow myservice
{% endhighlight %}

第一句的意思，就是当originserver挂了，不可层叠的请求（即hierarchy_stoplist定义的）就“可能”发往其他peer。

第二句的意思，就是所有优先originserver，只有挂了以后才去peer，这个配置针对的可cache的请求。

不过两句加起来，还有那些不再hierarchy_stoplist定义又不cache的（没实验，不知道这个可cache是指squid配置还是包括origin的header设置），可就没办法了，也不全面。

