---
layout: post
title: 淘宝TrafficServer的SSD分支测试与介绍
date: 2012-06-08
category: CDN
tags:
  - ats
---

同事介绍说淘宝有关于trafficserver的一个分支支持SSD的。下来试试。[下载地址](http://gitorious.org/trafficserver/taobao/commits/tbtrunk_ssd)

官方的ats安装过程很简单，这个分支稍微麻烦一些，因为有些包变成强制依赖了，包括：expat/openssl/pcre等。根据提示安装好再重新编译即可。

表面看几乎没什么差别，就是多了一个storage_ssd.config配置文件。

基础配置项说明网上都有，无外乎就是records.config里的监听，remap.config里的域名，storage.config里的目录。下面说几个比较怪异或者难受的地方：

1. trafficserver极其依赖DNS解析。我在parents.config中定义了多个parents的IP:port后，打开records.config里的debug信息，包括http.\*、dns.\*、cdn.\*和url.\*，结果发现ats针对每个url，会在获取完parents后依然去请求dns解析——注意这是在records.config里已经配置了no_dns_just_forward_to_parent为1之后，这种与字面意思严重不一样的结果让我很诧异……

2. 由于上面说的parent配置不可行，所以在remap.config中只能使用单个ip的方式回源。这里配置说明一般都说前后域名必须不一样，但是我在debug中没有发现这个逻辑，事实上ats不管这个事情，所谓不能一样，大概是怕本机dns解析回到自己变成loop吧。

3. 默认关于内存，是每1GB的磁盘启用1MB的内存。所以如果不指定的话，基本上磁盘的IO会很高很高！而最恶心的地方来了：配置里所有的数值都是以Byte为单位的，尼玛写4GB内存写的跟裹脚布一样长啊！

然后说测试。在性能方面，ats还是不错的。基本上我在单机走lo口，用http_load做压测，都是http_load先到瓶颈——因为http_load只用单核CPU。使用-p 1000的参数测试（因为最大只让开到1020），同机上的squid2.6.23、trafficserver和trafficserver-ssd三种，rps分别在6000，19000和14000的样子。first-bytes msec在10，4，1的样子，cpu在150％，25％，25％的样子。

以上是只用了4个域名每个域名1个url的小样本测试。实际运行起来应该不会这么高。

另：在需要dns解析的时候，14000的rps降到只有300＋，深表无语。

<hr />

线上流量运行测试后的补充：

* 不要使用文件存储，直接把裸设备交给ats管理！
* 预估好要缓存的文件的平均大小，默认是8000。ats和squid不一样的是这个值会影响ats的文件组织结构。每次修改都会重建缓存。
