---
layout: post
title: cacti自建tcp80连接数监控
date: 2010-03-24
category: monitor
tags:
  - cacti
---

同样作为提供web服务的机器，因为不同业务的关系，除了流量以外，还需要参考TCP80连接数来分析服务器性能状况。下面就试试cacti对连接数的监控。
最简单的方法，利用snmpnetstat这个命令，自动搞定一切。cactiuser.org上提供一个现成的模板，只要import就能直接用。下载地址如右：<a href="http://www.iammecn.com/wp-content/uploads/2009/12/cacti_graph_template_snmp_connections.zip" target="_blank">http://www.iammecn.com/wp-content/uploads/2009/12/cacti_graph_template_snmp_connections.zip</a>

不过这个snmpnetstat用起来精准度不太好保证，比如我在测试机上运行如下：

    [root@BeiJingBGP-Dns-02 ~]# snmpnetstat  -c 'public' -v 2c 10.10.10.43:161
    Active Internet (udp) Connections
    Proto Local Address
    udp   *.ntp
    udp   *.snmp
    udp   *.filenet-
    udp   *.54927
    udp   localhost.domain
    udp   localhost.ntp
    udp   localhost.domain
    udp   localhost.ntp
    udp   211.151.65.53.ntp
    udp   211.151.67.80.domain

居然一个tcp都没显示出来。我汗~~
所以采用一个自建脚本模板的方法来完成吧~~
首先在host上新建/etc/snmp/tcpconn.sh，内容如下：
{% highlight bash %}
#!/bin/sh
conn=`netstat -s -t | grep connections established |awk '{print $1}'`
echo $conn
{% endhighlight %}

对这个脚本我个人持保留意见。因为在netstat -anpl|grep :80|wc -l、netstat -s -t和/proc/net/tcp中来看，netstat -s -t最省时间，但数字也最不准~

三种方法测试如下：
    [root@BeiJingBGP-Dns-02 ~]# time netstat -s -t|awk '/connections established/{print $1}'
    3
    
    real    0m0.008s
    user    0m0.000s
    sys    0m0.008s
    [root@BeiJingBGP-Dns-02 ~]# time netstat -plna|awk '/:80/{a++}END{print a}'
    1
    
    real    0m0.065s
    user    0m0.000s
    sys    0m0.048s
    [root@BeiJingBGP-Dns-02 ~]# time awk '$4=="01"{a++}END{print a}' /proc/net/tcp
    
    real    0m0.023s
    user    0m0.000s
    sys    0m0.024s

（话说顺便试了一下|grep :80|wc -l和|awk '/:80/{a++}END{print a}'的time，awk快5ms，哈哈~）

然后在/etc/snmp/snmpd.cong里添加如下句：

    exec .1.3.6.1.4.1.2021.18 tcpCurrEstab /etc/snmp/tcpconn.sh

重启snmpd服务即可。

回cacti服务器端，运行如下命令，可以看到相关输出即可。

    [root@BeiJingBGP-Dns-02 ~]# snmpwalk -c 'public' -v 2c 10.10.10.43 .1.3.6.1.4.1.2021.18
    UCD-SNMP-MIB::ucdavis.18.1.1 = INTEGER: 1
    UCD-SNMP-MIB::ucdavis.18.2.1 = STRING: "tcpCurrEstab"
    UCD-SNMP-MIB::ucdavis.18.3.1 = STRING: "/etc/snmp/tcpconn.sh"
    UCD-SNMP-MIB::ucdavis.18.100.1 = INTEGER: 0
    UCD-SNMP-MIB::ucdavis.18.101.1 = STRING: "3"
    UCD-SNMP-MIB::ucdavis.18.102.1 = INTEGER: 0
    UCD-SNMP-MIB::ucdavis.18.103.1 = ""

这个string:"3"就是真正的tcp80连接数。
然后进入cacti的web页面进行设置吧：

在cacti界面中console->Templates->Data Templates，然后点击右上角的Add，Data Templates中的name是给这个数据模板的命名，Data Source中的name将来显示在Data Sources中，我这里添加“|host_description| – Tcp Conn. – ESTBLISHED”，选get snmp data，Internal Data Source Name也可以随便添，这个用来给rrd文件命名。设置完后就可以create了，之后会发现下面多了一些选项，在最下面那个添上我们需要的数据的OID“.1.3.6.1.4.1.2021.18.101.1”，可以save了。

此后需要创建一个Graph Templates，好让cacti生成图片。在cacti界面中console->Templates->Graph Templates，然后点击右上角的Add，Templates中的name是给这个数据模板的命名，Graph Template中的name是将来显示在图片上面中间的内容，我这里添加“|host_description| – Tcp Conn. –ESTBLISHED”，其他保持默认，保存之后上面会出来一些选项。在Graph Template Items中添加一个item，Data Source选之前添加的，color选择一个图片的颜色，Graph Item Type选AREA，也就是区域，也可以选其他的线条，Text Format设置说明。然后再添加一个，Graph Item Type选GPRINT，Consolidation Function选LAST，也就是当前的值，Text Format输入current。你还可以添加一些Graph Item Type为COMMENT的注释说明等。

最后，可以把graph加进host templates，或者直接在device中加graph。过一会就能看到图啦~~~


