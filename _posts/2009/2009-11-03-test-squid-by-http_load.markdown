---
layout: post
title: squid压力测试
date: 2009-11-03
category: testing
tags:
  - squid
  - http_load
---

向公司申请了台设备做测试机，打算把公司各种应用服务都自己练练，熟悉一下。先从最传统的squid开始做压力测试。先发一个小东东http_load的测试：

* 实验环境：

服务器硬件条件：内存2096M，CPU2.33GHz，硬盘70G；
Squid版本：Version 2.6.STABLE22

* 实验架构：

单台服务器：沈阳
web页面由nginx发布，采用基础配置，监听8080端口，网站页面类型包括.htm/html/css/js/xml；
前端由squid代理，采用公司默认配置，由cache_peer请求本机页面，监听80端口；
测试访问地点：北京

* 测试方法：

创建url文件，添加url记录共11条，其中html六条，js三条，css/xml各一条。（本来还有一个tar.gz文件，结果文件有近2M，影响测试结果，放弃）
根据网友经验，采取fetches参数配合parallel参数测试。

命令如下：./http_load -f 3000 -p 100 url > result.txt

根据情况调整parallel参数。

* 测试结果：

** 当p到180以上后，测试过程中就开始出现类似下面这样提示：

    http://www.test.com/ts.js: Connection timed out
    http://www.test.com/ts.js: byte count wrong

而结果中的fetches/sec则在650-850之间随机出现，属于不太稳定的状态了。而p再往上提高（我从200一直实验到500）， fetches/sec基本都在800左右，而msecs/connect则从50上升到255左右。
** 当p在140以下时，fetches/sec在1500以上，msecs/connect在0.2左右，bytes/sec在85000左右（此时服务器iptraf -d eth1查看流量大概每秒12M）；
** 当p到140以上后，f/s迅速下降到1000左右，ms/c则上升到10以上；parallel从150到180的过程中，f/s、ms/c和b/s基本是均速变化的；同时查看服务器的iostat或者vmstat，一般us在90%多，bo偶然有1出现（后来发现是因为我放的测试文件大小相差较大）。

* 实验结论

squid服务在并发数140以下时，能够提供优质的服务，140以上，性能逐渐下降，当并发数到200以上后，遭遇瓶颈，主要在CPU方面。

* 实验疑问

公司在线服务的设备，一般eth1流量都能跑到60M，有些甚至上了100M，这跟测试结果相差也太大了？

* 参考资料
<a href="http://www.hiadmin.com/tomcat-%e5%b9%b6%e5%8f%91%e6%b5%8b%e8%af%95/">http://www.hiadmin.com/tomcat-%e5%b9%b6%e5%8f%91%e6%b5%8b%e8%af%95/</a>
./http_load -parallel 200 -seconds 10 urls
    按照固定时间来结束测试,这样可以比较相同时间内被测服务器的响应速度.
    ./http_load -parallel 200 -fetches 1000 urls
    按照固定申请数来测试,这样可以比较相同访问量下返回的响应速度.
    虽然两者都可以获取到服务器的响应速度
    但是使用fetches更容易让被测服务器收到压力
    由于seconds控制测试时间,很有可能在短时间内测试客户端并没有发起足够数量的请求
    而服务端在收到足够压力之前,测试就已经结束了.
    有一些情况,诸如内存泄漏以及资源回收不利或者对后面的响应速度越来越慢等情况
    在这种测试条件下不容易发生
    而使用fetchs,能够让客户端保证确定请求数的全部处理.
    使用时间作为控制参数
    会由于测试人员不够耐心而人为将seconds参数设置过小
    导致测试结果失去意义
    所以,最后建议使用fetches作为测试参数.用以作为基准进行比较
    如果httpd_load获取到的页面数据和上次不一致
    则会报错byte count wrong
    如果是动态页面,由于返回数据内容不同.则此报错可以忽略
    
    
