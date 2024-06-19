---
layout: post
theme:
  name: twitter
title: tcpwrapper
date: 2009-11-03
category: linux
---

今天去新浪面试。有一道笔试题，考的是tcpwrapper的用法。因为没见过这个东东，所以百度一下，选几篇文章总结一下。

首先，tcpwrapper是unix上的工具，1990年就诞生了。至于它和iptables的不同，看到有人说是TCP/IP层的不同。说iptables是网络层的，tcpwrapper是应用层的。对不对，且看tcpwrapper的使用先：

1. 部署：首选当然是用安装包，要是编译源码，参见如下文：http://echo.sharera.com/blog/BlogTopic/9379.htm，虽然作者说自己笨笨的乱写，那也比我强多了

2. 开启日志：在/etc/syslog.conf里添加如下字段即可

tcpwrapper loglocal3.info /var/log/tcplog

这个时候要记得重启日志服务。可以使用kill -HUP syslogd进程号的方法（nnd，这也是今天的笔试题之一）。

3. 配置文件：/etc/hosts.allow

（本来还有个hosts.deny的）
编写规则是“servicename:hostname[:shellcmd]”

tcpwrapper监控的是inetd里的启动服务，用telnet举例如下

```bash
telnet:ALL
EXCEPT LOCAL, .M-gtuiw.com
echo "request from %d@%h:" >> /var/log/telnet.log;
if [ %h != "OS.M-gtuiw.com:" ] ; then
    finge -l @%h >> /var/log/telnet.log
fi
```
意即允许除了本机和M-gtuiw.com域下主机以外的所有telnet请求，并以“请求来自服务名@主机名”的方式记录进日志。（注意：EXCEPT也可以用在servicename后面）

和iptables一样（好像说反了，其实应该是iptables和tcpd一样），这个allow和deny的规则也是讲究先来后到的，所以会有个ALL:ALL:deny收尾（如果单有deny文件，就在里头写ALL:ALL就可以了）。

4. 调试

tcpdchk -v可以看到tcpd的全部规则设置和错误提示
tcpdmatch servicename hostname可以具体查询某条规则

5. inetd服务配置

相关的有两个文件，一个是/etc/services，这里定义了各种服务使用的协议和占用的端口（本文中出现的第三个新浪笔试考题了哦~~）；一个是/etc/inetd.conf，这里定义了各项服务的类型、协议、监听方式、用户、程序、参数——如果启用tcpwrapper的话，程序就都是/usr/sbin/tcpd了。比如telnet的配置行如下：

telnet    stream    tcp    nowait    root    /usr/sbin/tcpd    in.telnetd

6. 日志结果，直接摘抄一段如下：

```bash
Jul 31 22:00:52 [url]www.test.org[/url] in.telnetd[4365]: connect from 10.68.32.1
Jul 31 22:02:10 [url]www.test.org[/url] in.telnetd[4389]: connect from 10.68.32.5
Jul 31 22:04:58 [url]www.test.org[/url] in.ftpd[4429]: connect from 10.68.32.3
```

以上说了这么多，都是unix上的，最后来一句，在linux上，xinetd就是这个inetd+tcpwrapper了。何况还有强大的iptables……它可不像tcpwrapper只能管tcp协议的服务哦~~

参考文章：

<a href="http://jianjian.blog.51cto.com/35031/41949">http://jianjian.blog.51cto.com/35031/41949</a>
<a href="http://echo.sharera.com/blog/BlogTopic/9379.htm">http://echo.sharera.com/blog/BlogTopic/9379.htm</a>
<a href="http://blog.chinaunix.net/u/26264/showart_971334.html">http://blog.chinaunix.net/u/26264/showart_971334.html</a>
http://www.linuxdiyf.com/viewarticle.php?id=18335


