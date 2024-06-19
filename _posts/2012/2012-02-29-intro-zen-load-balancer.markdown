---
layout: post
theme:
  name: twitter
title: ZenLoadBalancer试用(一)
---

在微博上看到一款叫做Zen LoadBalancer的负载均衡软件更新新闻。于是决定下载来看看，其官网地址是：<http://www.zenloadbalancer.com/web/>。具体的说，是基于Debian构建的TCP/UDP负载均衡，通过perl的CGI页面完成对负载均衡的管理和监控，包括cluster功能(类似keepalived双机)。对后端real server的监控通过的是nagios-plugins里提供的check_http/check_smtp/check_ftp等一系列脚本完成的。监控通过SNMP完成，展示图像是rrd和GD::Graph。唯一没法知道的就是做负载均衡核心功能的pen这个东东，因为提供的是iso镜像，安装完后就直接有二进制文件在了，不知道这个pen到底是怎么做的……

## 下载安装

通过官网页面找到download即可，实际是托管在sf.net上。

安装步骤和普通的linux发行版光盘安装时一样的。作为实验，就只用电脑上的virtualbox挂载iso文件然后启动新虚拟机即可了。iso文件有225MB大，安装完成之后则是五百多兆，还是比较精简的了。

注意：在install的时候，会提示输入ip啊，gw啊之类的，如果有条件的话，最好就输正确的。因为在这步的时候zen就直接把输入结果写进zen配置文件而不是debian的/etc/network/interfaces了。然后每次重启zenloadbalancer都会根据zen的配置改变网络配置。

## 项目路径和关键文件

主要有两个启动脚本/etc/init.d/zenloadbalancer和/etc/init.d/mini_httpd，而zen的其他所有配置啊，执行文件啊，perl脚本啊，日志啊，都存放在/usr/local/zenloadbalancer目录下。

目录命名还算一目了然，主要有一个config和app比较混淆。

config里是用来存放负载均衡配置的地方，大多数情况下，这里的文件应该是通过webGUI自动生成的。包括if_*.conf指定网卡的(这也是唯一一个不全部由GUI生成的，如第一步所说，在install的时候会生成第一个eth0的配置)，cluster_*.conf指定高可用集群的配置，*_farms.conf指定具体某个instance的配置(类似keepalived.conf里的一个virtual_server{}配置)。

app里包括了zen的主要应用，比如mini_httpd、pen、zeninotify等。其他的也没啥可看的，因为用不上改动。

pen里有man可以看，比较引人的就是它可以限制前后两段的链接数，包括单独设定到每个realserver的链接数。从启动脚本和man来看，应该就是类似lvs的NAT模式，不知道官网说的30000链接是社区版运行的结果，还是他们硬件版的结果~另一个比较怪异的事情是zen里带上了命令用来从realserver上获取日志，其man文档说是因为zen的负载均衡会传递给后端自己的IP，所以需要在zen收集原始ip，然后跟后端的日志合并？但是实际在运行的webGUI上看到明明有X-Forwarder-For支持。不知道是不是man没更新了？

mini_httpd是一个常用于嵌入式开发的webserver，支持HTTP/1.1协议，支持CGI，支持SSL。zen里就是用这个来发布其webGUI的。可以命令行参数启动，也可以写一个简单的配置文件。在我的测试中，默认配置文件启动是有问题的，每次连接都会被reset by peer。strace的结果显示mini_httpd进程fork出来的child总是异常退出。不过从配置文件里挑几个必要的参数写在命令行里启动就没问题了。

## webGUI介绍

启动起来后，就可以登录操作的，默认采用了htpasswd控制访问权限，初始用户密码是admin/admin。首页是zenLB的监控图。

在farms的添加页里可以看到，负载均衡算法不多，就是轮训，哈希，权重，优先级。注意说明写的是每个clientIP做hash，而不是一般说的C段。而优先级的意思是：只在最高且相同优先级的server间均衡，除非都down掉了，才会指向低优先级的。

另外提供的功能还有：设定客户端保持时间，最大连接客户端数量，最大允许后端realserver数量，给httpheader加x-forwarder-for信息，启用nagios-plugins的外部监控等。

以上是tcp的配置，然后还可以具体的设置http/https的设置，注意https不是透传的，而是在zen上验证ssl，给后端的依然是http请求。

然后有zen自己的设置。主要有apt配置，可以添加apt源，包括zen自己的源，这样通过apt直接升级zenloadbalance。

然后有网卡设置。实际也就是通过ip addr命令添加咯。

然后有cluster设置。也就是在两台zenlb之间，通过ssh证书信任，共同使用另一个vip服务。也有master-slave抢占和slave-slave不抢占两种运行模式。两台zenlb之间，通过zenlate

ncy命令的UCARP服务来保持心跳，通过zeninotify传输master上的配置到slave。

然后还有日志、配置备份等功能……

页面上，还有一个和cluster VIP并列的选项是Vlan IP添加。但是在官网的指南上没看到相关内容，我点击后也没出现什么有意思的结果，怀疑会不会是未完成的功能。

基本上就是这样。手头没有机器给我折腾，只能笔记本电脑上解解眼馋了...

