---
layout: post
title: squid的snmp配置和部分oid说明
date: 2010-09-14
category: monitor
tags:
  - squid
  - snmp
---

首先配置squid.conf如下：
{% highlight squid %}
acl MonitorCenter src 127.0.0.1
acl snmppublic snmp_community public
snmp_access allow snmppublic MonitorCenter
snmp_access deny all
{% endhighlight %}

然后配置snmpd.conf如下：

    com2sec notConfigUser  default    public
    group   notConfigGroup v2c           notConfigUser
    view    systemview    included   .1.3.6.1.4.1.3495.1
    proxy -v 1 -c public 127.0.0.1:3401 .1.3.6.1.4.1.3495.1
    
分别重启squid和snmpd即可。
用snmpwalk -v 2c -c public 192.168.0.2 1.3.6.1.4.1.3495 -Cc就可以查看全部的数据了。对了解前段缓存有用的oid主要如下：

    SNMPv2-SMI::enterprises.3495.1.1.1.0 = INTEGER: 286800          内存缓存文件大小KB
    SNMPv2-SMI::enterprises.3495.1.1.2.0 = INTEGER: 1072480         磁盘缓存文件大小KB
    SNMPv2-SMI::enterprises.3495.1.3.1.3.0 = INTEGER: 387200        内存使用大小KB
    SNMPv2-SMI::enterprises.3495.1.3.1.5.0 = INTEGER: 8             进程使用CPU的比例
    SNMPv2-SMI::enterprises.3495.1.3.1.7.0 = Gauge32: 66757         缓存文件总数
    SNMPv2-SMI::enterprises.3495.1.3.1.10.0 = Gauge32: 225          可用文件描述符个数
    SNMPv2-SMI::enterprises.3495.1.3.1.12.0 = Gauge32: 799          当前使用中的文件描述符个数
    SNMPv2-SMI::enterprises.3495.1.3.2.1.15.0 = Gauge32: 90377      当前访问缓存的客户端总数
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.9.1 = INTEGER: 89        一分钟请求命中比
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.10.1 = INTEGER: 94       一分钟字节命中比
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.3.1 = INTEGER: 7         一分钟TCP_MISS/200比
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.4.1 = INTEGER: 0         一分钟TCP_IMS_HIT/304比
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.5.1 = INTEGER: 0         一分钟TCP_HIT/200比
    SNMPv2-SMI::enterprises.3495.1.3.2.2.1.11.1 = INTEGER: 45       一分钟TCP_REFRESH_HIT/304比
    ++++++++以上oid最后一位都可以改成任意时间（分钟为单位）进行统计++++++++
    SNMPv2-SMI::enterprises.3495.1.5.1.1.9.10.10.10.13 = Counter32: 324396    请求回某源的总数
    SNMPv2-SMI::enterprises.3495.1.5.2.1.2.58.31.229.71 = Counter32: 19       某客户ip的http请求数
    SNMPv2-SMI::enterprises.3495.1.5.2.1.3.58.31.229.71 = Counter32: 327      响应该IP请求的字节数KB
    SNMPv2-SMI::enterprises.3495.1.5.2.1.4.58.31.229.71 = Counter32: 17       响应该IP请求的命中率
    SNMPv2-SMI::enterprises.3495.1.5.2.1.5.58.31.229.71 = Counter32: 324      响应该IP请求的字节命中数KB
    
    
    
