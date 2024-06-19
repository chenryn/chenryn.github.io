---
layout: post
theme:
  name: twitter
title: 集群故障检查记录
date: 2010-10-27
category: linux
---

某服务器集群，是双lvs_keepalived+多nginx结构。最近突然发现流量监控出现较大波动，nginx的access.log时常出现持续几十秒的无外来访问情况（即只有LVS的ip过来的400探测）。

在两台lvs设备上的/var/log/messages上都看到大量的VIP切换记录：

Oct 22 09:47:12 localhost Keepalived_vrrp: VRRP_Instance(VI_10) Transition to MASTER STATE
Oct 22 09:47:13 localhost Keepalived_vrrp: VRRP_Instance(VI_10) Entering MASTER STATE
Oct 22 09:47:13 localhost Keepalived_vrrp: VRRP_Instance(VI_10) setting protocol VIPs.

Oct 22 09:47:14 localhost Keepalived_vrrp: VRRP_Instance(VI_10) Received higher prio advert
Oct 22 09:47:14 localhost Keepalived_vrrp: VRRP_Instance(VI_10) Entering BACKUP STATE
Oct 22 09:47:14 localhost Keepalived_vrrp: VRRP_Instance(VI_10) removing protocol VIPs.

相互之间ping丢包相当严重，而ping同一网段其他ip都没问题。

学来一个比较直观而且细腻的ping用法：ping -f $IP -c 5000

man上对-f的解释如下：

-f     Flood  ping.  For  every  ECHO_REQUEST  sent  a  period "." is printed, while for ever ECHO_REPLY received a backspace is printed.  This provides a rapid display of how many packets are being dropped.  If interval is not given, it sets  interval to zero and outputs packets as fast as they come back or one hundred times per second, whichever is more.  Only the superuser may use this option with zero interval.

-f    洪水ping，每当发送一个ECHO_REQUEST请求时，都在屏幕上打印一个点"."，而收到ECHO_REPLY时就退格一次。以此简洁明了的显示出丢了多少个包。如果不明确指定发包间隔，默认间隔时间为0，即收包有多快，发包就有多快，可能每秒100次，或许更快~注意：只有超级用户root才能不设间隔的使用洪水ping参数-f

我们把这个丢包.叫做贪吃蛇，哈哈~~

采用更换服务器网线、强制指定网卡速率等办法，丢包率从近30%下降到了5%，问题依然没有全部解决。最后重启机器，就OK了……真实问题是否和ipvs有关，待查ing
