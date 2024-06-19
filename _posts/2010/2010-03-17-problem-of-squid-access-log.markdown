---
layout: post
theme:
  name: twitter
title: squid 灵异日志
date: 2010-03-17
category: squid
---

今天在 squid 服务器上，无意看到一个让我无比惊讶的访问日志，随后一统计，同样的日志居然还不在少数，……

```bash
    [root@tinysquid2 ~]# tail -f /cache/logs/access.log |grep HIT
    1268824378.683     64 125.39.107.46 TCP_MEM_HIT/200 851 GET http://www.114.com.cn/style/css/jquery.autocomplete.css - DIRECT/117.25.130.146 text/css "http://www.114.com.cn/gindex.html" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; QQPinyin 686; SV1; 360SE)"
```

居然存在 `TCP_MEM_HIT/200` 的情况下还 `DIRECT` 回源的情况！！

有同事猜测可能是当源站数据取回来后，因为 `cache_mem` 不够大，要转写到 `cache_disk` 上去，但请求并发较大，数据还没转写呢，mem 已经不足了，于是把相对较老的抛弃掉。于是在索引中标记这部分数据是 HIT 的，但实际又没有数据在 MEM 中，所以继续 DIRECT 回源取了。

不过从 squidclient 的 mgr:info 来看，不支持他的这种说法。

```bash
    Cache information for squid:
        Request Hit Ratios:    5min: 45.4%, 60min: 55.7%
        Byte Hit Ratios:    5min: 59.2%, 60min: 62.3%
        Request Memory Hit Ratios:    5min: 30.1%, 60min: 24.4%
        Request Disk Hit Ratios:    5min: 26.8%, 60min: 24.0%
        Storage Swap size:    354184 KB
        Storage Mem size:    32196 KB
        Mean Object Size:    15.91 KB
        Requests given to unlinkd:    498
```

可以看到内存使用的很少，才 32M，而 free 是 3G，cache\_mem 是 1G。

还有，之后对全部日志进行分析时发现，cache\_status 不单单是 `TCP_MEM_HIT` 会出现这种情况，全部日志的情况如下：

```bash
    [root@tinysquid2 ~]# cat /cache/logs/access.log|grep HIT|grep DIRECT|grep -v REFRESH|awk '{print $4}'|sort|uniq -c
       1086 TCP_HIT/200
      18386 TCP_IMS_HIT/304
      45964 TCP_MEM_HIT/200
          2 TCP_MEM_HIT/206
```

即使是 DISK 上的 `TCP_HIT` 也有回源的。太奇怪了！！

