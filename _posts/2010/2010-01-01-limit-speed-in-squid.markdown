---
layout: post
title: squid限速
date: 2010-01-01
category: squid
---
squid有个delay_pool，可以做限速，虽然效果不太准~（嗯，就像限制并发连接数的maxconn一样）
首先搬个老虎皮做大旗——《Squid: The Definitive Guide》的相关段落：

The buckets don't actually store bandwidth (e.g., 100 Kbit/s), but    
rather some amount of traffic (e.g., 384 KB). Squid adds some    
amount of traffic to the buckets each second. Cache clients take    
some amount of traffic out when they receive data from an upstream    
source (origin server or neighbor).    
The size of a bucket determines how much burst bandwidth is    
available to a client. If a bucket starts out full, a client can    
take as much traffic as it needs until the bucket becomes empty.    
The client then receives traffic allotments at the fill rate.    
The mapping between Squid clients and actual buckets is a bit    
complicated. Squid uses three different constructs to do it: access    
rules, delay pool classes, and types of buckets. First, Squid    
checks a client request against the delay_access list. If the    
request is a match, it points to a particular delay pool. Each    
delay pool has a class: 1, 2, or 3. The classes determine which    
types of buckets are in use. Squid has three types of buckets:    
aggregate, individual, and network:    
A class 1 pool has a single aggregate bucket.    
A class 2 pool has an aggregate bucket and 256 individual    
buckets.    
A class 3 pool has an aggregate bucket, 256 network buckets, and    
65,536 individual buckets.    
As you can probably guess, the individual and network buckets    
correspond to IP address octets. In a class 2 pool, the individual    
bucket is determined by the last octet of the client's IPv4    
address. In a class 3 pool, the network bucket is determined by the    
third octet, and the individual bucket by the third and fourth    
octets.    
For the class 2 and 3 delay pools, you can disable buckets you    
don't want to use. For example, you can define a class 2 pool with    
only individual buckets by disabling the aggregate bucket.    
When a request goes through a pool with more than one bucket type,    
it takes bandwidth from all buckets. For example, consider a class    
3 pool with aggregate, network, and individual buckets. If the    
individual bucket has 20 KB, the network bucket 30 KB, but the    
aggregate bucket only 2 KB, the client receives only a 2-KB    
allotment. Even though some buckets have plenty of traffic, the    
client is limited by the bucket with the smallest amount.    
C.2 Configuring Squid    
Before you can use delay pools, you must enable the feature when    
compiling. Use the —enable-delay-pools option when running    
./configure. You can then use the following directives to set up    
the delay pools.    
C.2.1 delay_pools    
The delay_pools directive tells Squid how many pools you want to    
define. It should go before any other delay pool-configuration    
directives in squid.conf. For example, if you want to have five    
delay pools:    
delay_pools 5    
The next two directives actually define each pool's class and other    
characteristics.    
C.2.2 delay_class    
You must use this directive to define the class for each pool. For    
example, if the first pool is class 3:    
delay_class 1 3    
Similarly, if the fourth pool is class 2:    
delay_class 4 2    
In theory, you should have one delay_class line for each pool.    
However, if you skip or omit a particular pool, Squid doesn't    
complain.    
C.2.3 delay_parameters    
Finally, this is where you define the interesting delay pool    
parameters. For each pool, you must tell Squid the fill rate and    
maximum size for each type of bucket. The syntax is:    
delay_parameters N rate/size [rate/size [rate/size]]    
The rate value is given in bytes per second, and size in total    
bytes. If you think of rate in terms of bits per second, you must    
remember to divide by 8.    
Note that if you divide the size by the rate, you'll know how long    
it takes (number of seconds) the bucket to go from empty to full    
when there are no clients using it.    
A class 1 pool has just one bucket and might look like this:    
delay_class 2 1    
delay_parameters 2 2000/8000    
For a class 2 pool, the first bucket is the aggregate, and the    
second is the group of individual buckets. For example:    
delay_class 4 2    
delay_parameters 4 7000/15000 3000/4000    
Similarly, for a class 3 pool, the aggregate bucket is first, the    
network buckets are second, and the individual buckets are    
third:    
delay_class 1 3    
delay_parameters 1 7000/15000 3000/4000 1000/2000    
C.2.4 delay_initial_bucket_level    
This directive sets the initial level for all buckets when Squid    
first starts or is reconfigured. It also applies to individual and    
network    
buckets, which aren't created until first referenced. The value is    
a percentage. For example:    
delay_initial_bucket_level 75%    
In this case, each newly created bucket is initially filled to 75%    
of its maximum size.    
C.2.5 delay_access    
This list of access rules determines which requests go through    
which delay pools. Requests that are allowed go through the delay    
pools, while those that are denied aren't delayed at all. If you    
don't have any delay_access rules, Squid doesn't delay any    
requests.    
The syntax for delay_access is similar to the other access rule    
lists (see Section 6.2), except that you must put a pool number    
before the allow or deny keyword. For example:    
delay_access 1 allow TheseUsers    
delay_access 2 allow OtherUsers    
Internally, Squid stores a separate access rule list for each delay    
pool. If a request is allowed by a pool's rules, Squid uses that    
pool and stops searching. If a request is denied, however, Squid    
continues examining the rules for remaining pools. In other words,    
a deny rule causes Squid to stop searching the rules for a single    
pool but not for all pools.    
C.2.6 cache_peer no-delay Option    
The cache_peer directive has a no-delay option. If set, it makes    
Squid bypass the delay pools for any requests sent to that    
neighbor.    

然后说老实话：我也看不太懂……
只好贴一些百度出来的结果：
    class类型1为单个IP地址流量    
    class类型2为C类网段中的每个IP地址流量    
    class类型3为B类网段中的每个C类网段中的每个IP地址流量    
具体的说：
    类型1只有一个总带宽流量实际也就是这个IP地址的流量    
    delay_parameters 1 64000/64000    
    类型2有两个带宽流量参数，第一个为整个C类型网段流量，第二个为每个IP流量    
    delay_parameters 1 -1/-1 64000/64000    
    类型3有三个带宽流量参数,第一个为整个B类网总流量，第二个为每个B类网段中的C类网段总流量,第三个为了B类网段中每个C类网段中的每个IP流量    
    delay_parameters 1 -1/-1 -1/-1 64000/64000    
但似乎我还没百度到谁用class为2或者3的。一般大家都只用1……
举个例子：
两个域名，分别限制网民下载速度为50kb/s和100kb/s。配置如下：
{% highlight squid %}
#定义域名
acl LIMIT_A dstdomain a.test.com
acl LIMIT_B dstdomain b.test.com
#定义受限IP段
acl LIMIT_IP src 192.168.1.0/24
acl ALL src 0/0
#开启两个连接延迟池
delay_pools 2
#定义两个延迟池，class类型均为1
delay_class 1 1
delay_class 2 1
#分配域名到不同的延迟池
delay_access 1 allow LIMIT_A
delay_access 2 allow LIMIT_B
#受限网段延迟池
delay_access 1 allow LIMIT_IP
#定义下载速率，速率定位为restore(bytes/sec)/max(bytes)，，restore是表示以bytes/sec的速度下載object到bucket裡，而max則表示buckets的bytes值
delay_parameters 1 50000/50000
delay_parameters 2 100000/100000
#squid启动时初始化的池的带宽百分比
delay_initial_bucket_level 100
{% endhighlight %}
据网友的测试，当限速配置为20000/20000即20000/1024=19.53kb/s的时候，实际的下载速度大概在11-15kb/s之间。
