---
layout: post
title: keepalived故障一例
date: 2010-12-03
category: linux
---

一组lvs，以keepalived主从方式运行。今天早上突然收到VIP报警，所有的VIP都ping不通了。

上lvs运行ipvsadm -ln一看，计数表全是0！怀疑是slave霸占了MAC，于是keepalived restart了一次，故障依旧。然后再restart了一次master，顿时恢复正常。

然后分析messages中的详细信息，推理本次故障的过程如下：

故障前——masterA，slaveB

    0:00    A "kernel:eth1:link DOWN"，疑似网卡物理中断，自动降级成slave；    
    0:01    B检测A宕机，升级为master，send arp到交换机，add所有VIP；    
    0:40    A "kernel:eth1:link UP"，但配置应该是不自动抢占；    
    0:43    A检测B宕机，升级为master；    
    0:48    A发送arp刷新请求到交换机，add所有VIP，但因为是物理中断，目前A实际仍处于断网状态，有期间RIP检查的timeout为证；    
    1:10    A检测RIP的http status正常，即此时A的网络才正式恢复正常；    
    1:10    B检测发觉A的状态为master，降级为slave，remove所有VIP；    

在0:43的时候，masterA的ARP刷新请求没能发送到交换机，而交换机记录的对应地址就还是B的——但在1:10时，B自认为slave而移除了所有ip。导致ping失败！

故障解决过程解析：

1、重启B——因为B已经是slave，所以restart不会发送ARP刷新，无效；    
2、重启A——因为A自认是master，重启A导致keepalived切换，会触发B发送ARP刷新，恢复正常。

最终解决办法：

在keepalived.conf中添加garp_master_delay 30参数，让slave在升级成master后延时30s再发送一次arp刷新请求，以应对网卡硬件中断引起的这个问题。
