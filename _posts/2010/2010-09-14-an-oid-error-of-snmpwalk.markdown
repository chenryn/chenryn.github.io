---
layout: post
theme:
  name: twitter
title: snmpwalk的报错一例
date: 2010-09-14
category: monitor
tags:
  - snmp
---

在给squid配置了snmp后，用snmpwalk采集数据，总览一下：

snmpwalk 192.168.0.2 -v 2c -c public 1.3.6.1.4.1.3495

刷到最后爆出错误：

    SNMPv2-SMI::enterprises.3495.1.5.2.1.1.218.28.141.150 = IpAddress: 218.28.141.150
    SNMPv2-SMI::enterprises.3495.1.5.2.1.1.119.184.18.137 = IpAddress: 119.184.18.137
    Error: OID not increasing: SNMPv2-SMI::enterprises.3495.1.5.2.1.1.218.28.141.150
    >= SNMPv2-SMI::enterprises.3495.1.5.2.1.1.119.184.18.137

原来snmp默认在抓取oid的时候，是按顺序递增下去请求的，而squid的最后一个1.5.2.1类别，是客户端数据，IP是分散的，所以218没法增长到119，于是就出错退出了。
解决方法很简单，加上-Cc参数即可，help说明如下：

-C APPOPTS    Set various application specific behaviours:
     p:  print the number of variables found
     i:  include given OID in the search range
     I:  don't include the given OID, even if no results are returned
     c:  do not check returned OIDs are increasing
     t:  Display wall-clock time to complete the request

不过这里加上-Cc后，简直就是在刷屏了，无数客户端ip全部都要打印出来，慎用慎用……

