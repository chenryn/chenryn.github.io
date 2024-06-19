---
layout: post
theme:
  name: twitter
title: squidclient用法
date: 2009-11-21
category: squid
---

squidclient是squid自带的一个小工具，一般用的最多的，就是-m purge URL了。
其实还有别的用法（看看help吧，不过这个慢慢来~~）先说一个大全式的用法（其他的具体用法，大不了用这里rep出来好了）：squidclient -p 80 mgr:info，显示如下：

[root@raocl ~]# /home/squid/bin/squidclient -p 80 mgr:info
    HTTP/1.0 200 OK
    Server:
    squid/2.6.STABLE21
    squid版本
    Date: Sat, 21 Nov 2009 03:58:45 GMT
    Content-Type: text/plain
    Expires: Sat, 21 Nov 2009 03:58:45 GMT
    Last-Modified: Sat, 21 Nov 2009 03:58:45 GMT
    X-Cache: MISS from cdn.21vianet.com
    Connection: close
    Squid Object Cache: Version 2.6.STABLE21
    Start Time: Sat, 21 Nov 2009 03:48:16 GMT
    Current Time: Sat, 21 Nov 2009 03:58:45 GMT
    Connection information for squid:
    Number of clients accessing
    cache: 1
    当前链接客户端数量
    Number of HTTP requests
    received: 2
    当前链接请求数
    Number of ICP messages
    received: 0
    Number of ICP messages
    sent: 0
    Number of queued ICP
    replies: 0
    Number of HTCP messages
    received: 0
    Number of HTCP messages
    sent: 0
    Request failure ratio:
    0.00
    Average HTTP requests per minute since
    start: 0.2
    每分钟链接请求数
    Average ICP messages per minute since
    start: 0.0
    Select loop called: 118332 times, 5.309 ms
    avg
    Cache information for squid:
    Request Hit Ratios: 5min: 0.0%,
    60min:
    0.0%
    五分钟cache请求数命中率
    Byte Hit Ratios: 5min: -0.0%,
    60min:
    100.0%
    五分钟cache字节数命中率
    Request Memory Hit Ratios: 5min:
    0.0%, 60min: 0.0%
    Request Disk Hit Ratios: 5min:
    0.0%, 60min: 0.0%
    Storage Swap size: 6224
    KB                                                         cache_dir使用大小
    Storage Mem size: 104
    KB                                                            cache_mem使用大小
    Mean Object Size: 4.60 KB
    Requests given to
    unlinkd: 0
    Median Service Times (seconds)  5
    min    60
    min:
    HTTP Requests
    (All):
    0.00000  0.00000
    Cache
    Misses:
    0.00000  0.00000
    Cache
    Hits:
    0.00000  0.00000
    Near
    Hits:
    0.00000  0.00000
    Not-Modified Replies:
    0.00000  0.00000
    DNS
    Lookups:
    0.00000  0.00000
    ICP
    Queries:
    0.00000  0.00000
    Resource usage for squid:
    UP Time: 628.201 seconds
    CPU Time: 0.216 seconds
    CPU Usage: 0.03%
    CPU Usage, 5 minute
    avg: 0.00%
    CPU Usage, 60 minute
    avg: 0.04%
    Process Data Segment Size via sbrk(): 3040
    KB
    Maximum Resident Size: 0 KB
    Page faults with physical i/o: 0
    Memory usage for squid via mallinfo():
    Total space in
    arena:    3052
    KB
    Ordinary
    blocks:
    3038
    KB
    7 blks
    Small
    blocks:
    0
    KB
    0 blks
    Holding
    blocks:
    231572
    KB
    5 blks
    Free Small
    blocks:
    0 KB
    Free Ordinary
    blocks:
    13 KB
    Total in
    use:
    234610 KB 100%
    Total
    free:
    13 KB 0%
    Total
    size:
    234624 KB
    Memory accounted for:
    Total
    accounted:
    571 KB
    memPoolAlloc calls: 76381
    memPoolFree calls: 71547
    File descriptor usage for squid:
    Maximum number of file
    descriptors:
    655360
    系统文件描述符个数
    Largest file desc currently in
    use:
    44
    使用过的最大个数
    Number of file desc currently in
    use:
    41
    目前使用中的个数
    Files queued for
    open:
    0
    Available number of file descriptors:
    655319
    Reserved number of file
    descriptors:   100
    Store Disk files
    open:
    0
    IO loop
    method:
    epoll
    Internal Data Structures:
    1379
    StoreEntries                                                              cache_dir中的文件个数
    26 StoreEntries with
    MemObjects
    mem中的文件个数
    25 Hot Object Cache
    Items
    热点文件个数
    1353 on-disk objects

另外，还有一个squidclient -p 80 mgr:objects，号称是慎用的大杀器，能够列出缓存文件列表——问题是：我找了个新开squid的测试机一试，发现列表显示内容是这个样子的：
    KEY 29E6623108A3E8A64DBBD016AB239AEA
    STORE_OK
    NOT_IN_MEMORY SWAPOUT_DONE
    PING_NONE
    CACHABLE,DISPATCHED,VALIDATED
    LV:1258460822 LU:1258461412 LM:1258460823
    EX:1260950400
    0 locks, 0 clients, 1 refs
    Swap Dir 0, File 0X000412
上头是32位MD5值么？谁看的懂呢……


