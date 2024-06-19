---
layout: post
theme:
  name: twitter
title: 日志流量计算
date: 2010-07-28
category: bash
tags:
  - awk
---

一般来说流量带宽是通过snmp协议取网卡流量画图。不过有的时候，为了优化分析或者排错，也会直接去计算服务的访问流量。方法很简单，根据日志中记录的请求时间（squid记录的是请求响应完成时间，如果要精确，可以再减去响应时间，不过一般squid的文件不至于5分钟内还传不完的……），按每5分钟一汇总其字节数，然后均摊到300秒上。

计算全日志中最高带宽的命令行如下：

```bash
cat $ACCESS_LOG|awk -F'[: ]' '{a[$5":"$6]+=$14}END{for(i in a){print i,a[i]}}'|sort|awk '{a+=$2;if(NR%5==0){if(a>b){b=a;c=$1};a=0}}END{print c,b*8/300/1024/1024}'
```
（日志为标准apache日志格式）
而把最后的awk改成'{a+=$2;if(NR%5==0){print $1,a*8/300/1024/1024;a=0}}'，就可以输出每5分钟时的流量值，然后用GD库画图~~（有时间看看perl的GD:Graph模块，应该不难）

