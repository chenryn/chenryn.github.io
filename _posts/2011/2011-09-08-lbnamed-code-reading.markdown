---
layout: post
title: lbnamed代码浅读
date: 2011-09-08
category: perl
---

群里听说lbnamed这么个东东，用perl实现的动态DNS服务器。程序包括三个perl模块：Stanford::DNSserver模块、Stanford::DNS模块、LBCD模块；三个perl程序：lbnamed主程序、poller探测程序、slbcd监控程序（这个有C语言的版本）。

* 先看主程序lbnamed。

排除掉sig啊，help啊，pid啊，log啊之类的以后，剩下的主要内容包括：

1. 一个Stanford::DNSserver->new()对象，分别用add_static和add_dynamic方法加入的DNS记录，然后用answer_queries方法启动运行。
2. 一个handle_lb_request()函数，用在add_dynamic中完成动态DNS解析响应。
3. 一个load_config()函数，用于从文件中读取domain/ip/weight的值并存入hash。
4. 一个by_weight()函数，用于排序。

* 接下来主要是去看Stanford::DNSserver里的add_*和answer_queries函数。

这个模块里，$self除了new()传递的参数以外，还有几个很重要的空间，分别是$self->{select}、$self->{static}->{$domain}->{$type}->{answer}、$self->{static}->{$domain}->{$type}->{ancount}和$self->{dynamic}->{$domain}。
1. add_static()很简单，把传入的配置按照格式组装给Stanford::DNS::dns_answer()，返回值存入$self->{static}->{$domain}->{$type}->{answer}，同时$self->{static}->{$domain}->{$type}->{ancount}加1。
<pre><code>
*** 2011-10-09注: 代码是.=，即返回值是接入，static方法可以返回多条记录，而dynamic方法只会返回最后加载的一条。
</code></pre>
1. add_dynamic()更简单，直接把lbnamed里的handle_lb_request()的引用存入$self->{dynamic}->{$domain}就完了。
2. answer_queries()方法启动服务器，步骤如下：

 $self->daemon()，其实就是改变STD后的fork。<br />
 $self->init()，首先用IO::Socket::INET模块，new出两个socket，分别监听在TCP/UDP的DNS端口上；然后调用$self->{select}，这在new的时候已经创建了一个IO::Select对象。把之前的两个socket加入到select队列中。<br />
 在一个while(1){}死循环中，调用select的can_read()方法，具体是$self->{select}->can_read(600)，根据IO::Select的说明，这个600表示如果一直没有可以READ的SOCKET，等待600秒后返回一个空队列，也就是说轮训的时候，每个socket会阻塞600秒~<br />
 如果can_read成立，根据其协议是UDP还是TCP，调用$self->handle_udp_req或者$self->handle_tcp_req处理这个socket。

* 然后看$self->handle_udp_req()方法。

1. 用perl内嵌的recv方法，从socket中读取8192字节到$buff，至于这里为什么是8192字节，没有找到比较合理的解释。因为DNS协议的UDP传输一般只有512字节，而UDP协议的不可靠性，也很难保证8192字节的数据完整。唯一在一篇博客上看到说因为NFS的读写数据大小是这个。反正不管怎么样，8192肯定是足够的；
2. 把$buff传递给$self->do_dns_request()函数，返回值赋为$reply。
3. 用send方法，把$reply发回给socket。

* 再来看$self->handle_tcp_req()方法。

1. 用IO::Socket::INET::accept()方法创建一个返回到对端的socket对象；
2. 关闭原来的socket，释放IO::Select；
3. 使用perl内嵌的sysread方法，从socket中读入2个字节到$buff，然后用unpack('n',$buff)的方式解压得到数据长度；
4. 根据计算的长度，继续读入相应长度的数据，并传递给$self->do_dns_request()函数，返回值赋为$reply；
5. 用pack('n',length $reply)打包数据长度，接在数据报文的头部，用send方法发送出去；
6. 依上面三步的操作，循环进行，直到socket内数据全部读取完成。

* 然后看$self->do_dns_request()方法。

1. 先把buff里的前12字节取出来，然后用unpack('n6C*',$buff)解压成RFC1035标准里的包头信息，包括：
<pre><code>
    $id——用来验证请求和响应匹配的随机数, 
    $flags——包括$opcode查询类型（正向/反向）、$qr（请求/响应）、$tc（截断？）、$rd（是否递归）, 
    $qdcount——查询的问题个数, 
    $ancount——响应的结果个数, 
    $aucount——额，这个在RFC1035里都没发现, 
    $adcount——附加区域内的响应结果个数。从程序来看，aucount和adcount一直都是0。
</code></pre>
2. 然后用Stanford::DNS::dn_expand()解析$buff出$qname，用unpack('nn', substr($buff, $ptr, 4))解析出$qtype和$qclass，这三个变量是RFC1035.4.1.3中定义的请求区内容。
3. 最后，使用$self->check_static($qname,$qtype,$qclass,\%dnsmsg)或$self->check_dynamic($qname,$qtype,$qclass,\%dnsmsg,$from)方法，得到响应内容，然后pack('n6', $id, $flags, $qdcount, $dnsmsg{ancount}, $dnsmsg{aucount}, $dnsmsg{adcount}) . $reply组装完成返回。
<pre><code>
*** 2011-10-09注: 代码是if( * or * )，即是先检查check_static结果并返回，只有不存在static的情况下，才会check_dynamic去！
</code></pre>
上面关于pack/unpack语焉不详，实在是自己也不懂……汗！

* 然后看check_static()函数

很简单，从前面add_static存入的%{$self->{static}}里取出对应qname的value即可，同时计算一下ancount。

* 接着是check_dynamic()函数

跟static不同的是，这里对域名进行了分割然后重拼装，在获取到最先匹配的handler后跳出循环，调用handler处理。举例说：team.www.domain.com这个域名，它先检查是不是存在$self->{dynamic}->{www.domain.com}，有就传递('www.domain.com','team',...)；否则下一步检查$self->{dynamic}->{domain.com}，有就传递('domain.com','team.www',...)；依此类推……
<br />至于Stanford::DNS模块，主要就是拼装各种数据成DNS协议规范的数据格式，在没看懂RFC1035和pack/unpack的用法前，就不写了。

* 回头继续看那个handler函数

1. 在new的时候，调用了&do_reload()做loopfunc；
2. do_reload()中调用了load_config("${poller_results}lb")读取poller的结果文本；
3. load_config()中将groups数组作为key，存入了各项数值，weight、ttl、rnd等；
4. unless ($group = $lb_groups{$qname})这里就是用到了上一步的key，确认域名存在；
5. by_weight()中，用$weight{}对$host排序；
6. 选出最终答案，$rnd{$qname} ? @$group[int(rand(min($rnd{$qname},$#$group)))] : @$group[0];不过在load_config中，$rnd{$group}=0（另外一个赋值的地方是$rnd{$weight}=$host，很没道理的地方，我都怀疑是不是写反了？），所以肯定是从数组拿第一个，也就是最大的一个了。

* server部分完毕，然后看poller程序：

1. 大同小异的也是在while(1){...;sleep(120)}中用IO::Select和IO::Socket::INET完成对host的探测；
2. 然后dump_lb()函数里取出各host的探测结果，计算weight，写入文件。

这个计算方法主要包括了服务器的登录user数量和loadavg的大小。说实话我不清楚为啥要计算user数量……具体的数据格式，可以看LBCD.pm里注释的C语言typeof struct定义，也可以看slbcd脚本里的pack。如下：

```perl
$reply = pack("nnnnNNNnnnnnCC",            # build the reply
              $version, $id, $op, $status,
              $btime, time(), $utime,
              $l1, $l5, $l15, $tot, $uniq,
              $console, $reserved);
```

* 最后总结

这个server利用poller调整解析的weight，但并不是我想象中的百分比解析，而是针对每次解析请求时后端服务器的准实时（120秒）负载情况给出最适合的一个。对于全网GSLB，感觉不太适用；对于内部SLB，又感觉不如LVS好用。<br />
不过作为一个DNS框架，如果抛开poller，倒也可以自己再设想一个动态dns来：

1. 用Net::IP::Match::Regexp匹配ip列表到area区域——可以注意到，lbnamed中写的handler中没有用上传递进去的$from；
2. 然后$file是area区域到host/weight(100%)的对应，handler中取rand(100)随机数，跟设定的weight比大小，确定具体用哪个ip；
3. 最后改造poller，根据流量，响应时间等，确定一个weight阈值，超标的话就修改$file中得weight大小。
