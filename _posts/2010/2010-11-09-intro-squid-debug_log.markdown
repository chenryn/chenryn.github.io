---
layout: post
title: squid的debug日志
date: 2010-11-09
category: squid
---

今天为了检查防盗链配置，打开了squid的debug日志(squid.conf: debug_options ALL,9)。tailf观察，很是学习了一番squid的工作模式。

1、空闲时日志也一直在滚动，诸如“do_comm_select: 0 fds ready”、“storeDirClean: Cleaning directory /tmpfs/cache/03/2D”这样，第一个很显然就是表示TCPsocket可以accept请求；第二个是定期清除过期目录；

2、发送请求之后，accept部分如下：

2010/11/09 19:18:18| fd_open FD 15 HTTP Request
2010/11/09 19:18:18| httpAccept: FD 15: accepted port 80 client 124.238.250.28:39168
2010/11/09 19:18:18| cbdataLock: 0x7589c8
2010/11/09 19:18:18| comm_add_close_handler: FD 15, handler=0x4218f0, data=0x9a14f8
2010/11/09 19:18:18| cbdataLock: 0x9a14f8
2010/11/09 19:18:18| commSetTimeout: FD 15 timeout 300
2010/11/09 19:18:18| commSetSelect: FD 15 type 1
2010/11/09 19:18:18| commSetEvents(fd=15)
2010/11/09 19:18:18| comm_call_handlers(): got fd=15 read_event=1 write_event=0 F->read_handler=0x423370 F->write_handler=(nil)
2010/11/09 19:18:18| comm_call_handlers(): Calling read handler on fd=15
2010/11/09 19:18:18| clientReadRequest: FD 15: reading request...
2010/11/09 19:18:18| cbdataLock: 0x9a14f82010/11/09 19:18:18| cbdataValid: 0x9a14f8

3、读取请求信息，创建entry空间，如下：

2010/11/09 19:18:18| Parser: retval 1: from 0->68: method 0->2; url 4->57; version 59->67 (1/0)

2010/11/09 19:18:18| parseHttpRequest: Method is 'GET'

2010/11/09 19:18:18| parseHttpRequest: URI is 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| parseHttpRequest: req_hdr = {Referer: http://w.china.com

User-Agent: Wget/1.10.2 (Red Hat modified)

Accept: */*

Host: shanzhai.china.com

}

2010/11/09 19:18:18| parseHttpRequest: prefix_sz = 183, req_line_sz = 69

2010/11/09 19:18:18| parseHttpRequest: Request Header is

&nbsp;

Referer: http://w.china.com

User-Agent: Wget/1.10.2 (Red Hat modified)

Accept: */*

Host: shanzhai.china.com

&nbsp;

2010/11/09 19:18:18| parseHttpRequest: Complete request received

2010/11/09 19:18:18| commSetTimeout: FD 15 timeout 86400

2010/11/09 19:18:18| init-ing hdr: 0x9604f8 owner: 1

2010/11/09 19:18:18| parsing hdr: (0x9604f8)

Referer: http://w.china.com

User-Agent: Wget/1.10.2 (Red Hat modified)

Accept: */*

Host: shanzhai.china.com

&nbsp;

2010/11/09 19:18:18| creating entry 0x9a5610: near 'Referer: http://w.china.com'

2010/11/09 19:18:18| created entry 0x9a5610: 'Referer: http://w.china.com'

2010/11/09 19:18:18| 0x9604f8 adding entry: 45 at 0

2010/11/09 19:18:18| creating entry 0x847c10: near 'User-Agent: Wget/1.10.2 (Red Hat modified)'

2010/11/09 19:18:18| created entry 0x847c10: 'User-Agent: Wget/1.10.2 (Red Hat modified)'

2010/11/09 19:18:18| 0x9604f8 adding entry: 50 at 1

2010/11/09 19:18:18| creating entry 0x9a4d20: near 'Accept: */*'

2010/11/09 19:18:18| created entry 0x9a4d20: 'Accept: */*'

2010/11/09 19:18:18| 0x9604f8 adding entry: 0 at 2

2010/11/09 19:18:18| creating entry 0x9a1cb0: near 'Host: shanzhai.china.com'

2010/11/09 19:18:18| created entry 0x9a1cb0: 'Host: shanzhai.china.com'

2010/11/09 19:18:18| 0x9604f8 adding entry: 27 at 3

2010/11/09 19:18:18| removing 183 bytes; conn->in.offset = 0

2010/11/09 19:18:18| 0x9604f8 lookup for 20

2010/11/09 19:18:18| clientSetKeepaliveFlag: http_ver = 1.0

2010/11/09 19:18:18| clientSetKeepaliveFlag: method = GET

2010/11/09 19:18:18| 0x9604f8 lookup for 41

2010/11/09 19:18:18| 0x9604f8 lookup for 9

2010/11/09 19:18:18| 0x9604f8 lookup for 52

2010/11/09 19:18:18| 0x9604f8 lookup for 41

2010/11/09 19:18:18| 0x9604f8 lookup for 9

2010/11/09 19:18:18| 0x9604f8 lookup for 59

2010/11/09 19:18:18| cbdataLock: 0x734ed8

2010/11/09 19:18:18| cbdataLock: 0x9a14f8

2010/11/09 19:18:18| cbdataLock: 0x9a17a8

2010/11/09 19:18:18| cbdataValid: 0x734ed8

&nbsp;

至此完成了请求信息的存取，并保持HTTP/1.0下的keepalive。

&nbsp;

4、请求acl检查部分

2010/11/09 19:18:18| aclCheck: checking 'http_access allow swfs !notnull_refer'

2010/11/09 19:18:18| aclMatchAclList: checking swfs

2010/11/09 19:18:18| aclMatchAcl: checking 'acl swfs url_regex -i ^http://flash.shanzhai.china.com/swfsimple/com/china/ceuf/map/.*\.swf'

2010/11/09 19:18:18| aclMatchRegex: checking 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| aclMatchRegex: looking for '^http://flash.shanzhai.china.com/swfsimple/com/china/ceuf/map/.*\.swf'

2010/11/09 19:18:18| aclMatchAclList: no match, returning 0

2010/11/09 19:18:18| cbdataLock: 0x734b68

2010/11/09 19:18:18| cbdataUnlock: 0x734ed8

2010/11/09 19:18:18| cbdataValid: 0x734b68

2010/11/09 19:18:18| aclCheck: checking 'http_access deny pics !notnull_refer'

2010/11/09 19:18:18| aclMatchAclList: checking pics

2010/11/09 19:18:18| aclMatchAcl: checking 'acl pics url_regex -i \.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$'

2010/11/09 19:18:18| aclMatchRegex: checking 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| aclMatchRegex: looking for '\.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$'

2010/11/09 19:18:18| aclMatchRegex: match '\.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$' found in 'http://shanzhai.china.com/images/simple/siteGuid

eR.gif'

2010/11/09 19:18:18| aclMatchAclList: checking !notnull_refer

2010/11/09 19:18:18| aclMatchAcl: checking 'acl notnull_refer referer_regex .'

2010/11/09 19:18:18| aclMatchRegex: checking 'http://w.china.com'

2010/11/09 19:18:18| aclMatchRegex: looking for '.'

2010/11/09 19:18:18| aclMatchRegex: match '.' found in 'http://w.china.com'

2010/11/09 19:18:18| aclMatchAclList: no match, returning 0

2010/11/09 19:18:18| cbdataLock: 0x735308

2010/11/09 19:18:18| cbdataUnlock: 0x734b68

2010/11/09 19:18:18| cbdataValid: 0x735308

2010/11/09 19:18:18| aclCheck: checking 'http_access deny pics !domain_refer'

2010/11/09 19:18:18| aclMatchAclList: checking pics

2010/11/09 19:18:18| aclMatchAcl: checking 'acl pics url_regex -i \.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$'

2010/11/09 19:18:18| aclMatchRegex: checking 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| aclMatchRegex: looking for '\.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$'

2010/11/09 19:18:18| aclMatchRegex: match '\.(jpg|gif|jpeg|png|mp3|smi|wma|swf)$' found in 'http://shanzhai.china.com/images/simple/siteGuid

eR.gif'

2010/11/09 19:18:18| aclMatchAclList: checking !domain_refer

2010/11/09 19:18:18| aclMatchAcl: checking 'acl domain_refer referer_regex -i ^http://[^/]*china.com ^http://124\.238\.253\.*'

2010/11/09 19:18:18| aclMatchRegex: checking 'http://w.china.com'

2010/11/09 19:18:18| aclMatchRegex: looking for '^http://[^/]*china.com'

2010/11/09 19:18:18| aclMatchRegex: match '^http://[^/]*china.com' found in 'http://w.china.com'

2010/11/09 19:18:18| aclMatchAclList: no match, returning 0

2010/11/09 19:18:18| cbdataLock: 0x7355a8

2010/11/09 19:18:18| cbdataUnlock: 0x735308

2010/11/09 19:18:18| cbdataValid: 0x7355a8

2010/11/09 19:18:18| aclCheck: checking 'http_access allow Safe_ports Domain'

2010/11/09 19:18:18| aclMatchAclList: checking Safe_ports

2010/11/09 19:18:18| aclMatchAcl: checking 'acl Safe_ports port 80'

2010/11/09 19:18:18| aclMatchAclList: checking Domain

2010/11/09 19:18:18| aclMatchAcl: checking 'acl Domain dstdomain .china.com'

2010/11/09 19:18:18| aclMatchDomainList: checking 'shanzhai.china.com'

2010/11/09 19:18:18| aclMatchDomainList: 'shanzhai.china.com' found

2010/11/09 19:18:18| aclMatchAclList: returning 1

2010/11/09 19:18:18| aclCheck: match found, returning 1

2010/11/09 19:18:18| cbdataUnlock: 0x7355a8

2010/11/09 19:18:18| aclCheckCallback: answer=1

2010/11/09 19:18:18| cbdataValid: 0x9a17a8

2010/11/09 19:18:18| The request GET http://shanzhai.china.com/images/simple/siteGuideR.gif is ALLOWED, because it matched 'Domain'

对照squid.conf，发现acl检测是从上到下依次进行（一般acl都这样），且http_access后最多只能有2个aclname

&nbsp;

5、rewrite部分

2010/11/09 19:18:18| clientRedirectStart: 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| clientRedirectDone: 'http://shanzhai.china.com/images/simple/siteGuideR.gif' result=NULL

2010/11/09 19:18:18| clientStoreURLRewriteStart: 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| clientStoreURLRewriteDone: 'http://shanzhai.china.com/images/simple/siteGuideR.gif' result=NULL

&nbsp;

6、cache配置

2010/11/09 19:18:18| clientInterpretRequestHeaders: REQ_NOCACHE = NOT SET

2010/11/09 19:18:18| clientInterpretRequestHeaders: REQ_CACHABLE = SET

2010/11/09 19:18:18| clientInterpretRequestHeaders: REQ_HIERARCHICAL = SET

7、cache_store检查

2010/11/09 19:18:18| clientProcessRequest: GET 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| 0x9604f8 lookup for 53

2010/11/09 19:18:18| storeGet: looking up 15EBB8A96296D7407EA1D03F075666BC

2010/11/09 19:18:18| clientProcessRequest2: default HIT

2010/11/09 19:18:18| clientProcessRequest: TCP_HIT for 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| storeLockObject: (client_side.c:3544): key '15EBB8A96296D7407EA1D03F075666BC' count=1

2010/11/09 19:18:18| storeAufsDirRefObj: referencing 0x753680 0/272

2010/11/09 19:18:18| storeLockObject: (store_client.c:122): key '15EBB8A96296D7407EA1D03F075666BC' count=2

2010/11/09 19:18:18| storeAufsDirRefObj: referencing 0x753680 0/272

2010/11/09 19:18:18| storeClientCopy: 15EBB8A96296D7407EA1D03F075666BC, seen 0, want 0, size 4096, cb 0x41dd90, cbdata 0x9a17a8

2010/11/09 19:18:18| cbdataLock: 0x9a17a8

2010/11/09 19:18:18| cbdataLock: 0x9a2178

2010/11/09 19:18:18| storeClientCopy2: 15EBB8A96296D7407EA1D03F075666BC

2010/11/09 19:18:18| storeClientCopy3: Copying from memory

2010/11/09 19:18:18| stmemCopy: offset 0: size 4096

2010/11/09 19:18:18| cbdataValid: 0x9a17a8

2010/11/09 19:18:18| clientCacheHit: http://shanzhai.china.com/images/simple/siteGuideR.gif = 200

&nbsp;

8、过期时间

2010/11/09 19:18:18| refreshCheck: 'http://shanzhai.china.com/images/simple/siteGuideR.gif'

2010/11/09 19:18:18| FRESH: expires 1320836796 >= check_time 1289301498

2010/11/09 19:18:18| Staleness = -1

2010/11/09 19:18:18| refreshCheck: Matched '<none> 0 20% 259200'

2010/11/09 19:18:18| refreshCheck: age = 702

2010/11/09 19:18:18|    check_time:    Tue, 09 Nov 2010 11:18:18 GMT

2010/11/09 19:18:18|    entry->timestamp:  Tue, 09 Nov 2010 11:06:36 GMT

2010/11/09 19:18:18| clientCacheHit: refreshCheckHTTPStale returned 0

2010/11/09 19:18:18| clientCacheHit: HIT

&nbsp;

9、继续完成entry

……2010/11/09 19:18:18| destroying entry 0x9a4cc0: 'Connection: keep-alive'

……2010/11/09 19:18:18| created entry 0x9a4c60: 'Connection: close'

&nbsp;

10、响应acl检查部分

2010/11/09 19:18:18| aclCheck: checking 'http_reply_access allow all'

2010/11/09 19:18:18| aclMatchAclList: checking all

2010/11/09 19:18:18| aclMatchAcl: checking 'acl all src 0.0.0.0/0.0.0.0'

2010/11/09 19:18:18| aclMatchIp: '124.238.250.28' found

2010/11/09 19:18:18| aclMatchAclList: returning 1

2010/11/09 19:18:18| aclCheck: match found, returning 1

2010/11/09 19:18:18| cbdataUnlock: 0x731988

2010/11/09 19:18:18| aclCheckCallback: answer=1

2010/11/09 19:18:18| cbdataValid: 0x9a17a8

2010/11/09 19:18:18| The reply for GET http://shanzhai.china.com/images/simple/siteGuideR.gif is ALLOWED, because it matched 'all'

2010/11/09 19:18:18| packing sline 0x9a5010 using 0x7fffdb895d10:

2010/11/09 19:18:18| HTTP/1.1 200 OK

&nbsp;

11、传输文件

2010/11/09 19:18:18| packing hdr: (0x9a5028)

2010/11/09 19:18:18| comm_write: FD 15: sz 362: hndl 0x424d60: data 0x9a17a8.

2010/11/09 19:18:18| cbdataLock: 0x9a17a8

2010/11/09 19:18:18| commSetSelect: FD 15 type 2

2010/11/09 19:18:18| commSetEvents(fd=15)

2010/11/09 19:18:18| cbdataUnlock: 0x9a17a8

2010/11/09 19:18:18| cbdataUnlock: 0x9a14f8

2010/11/09 19:18:18| cbdataFree: 0x846f18

2010/11/09 19:18:18| cbdataFree: Freeing 0x846f18

2010/11/09 19:18:18| cbdataUnlock: 0x9a17a8

&nbsp;
