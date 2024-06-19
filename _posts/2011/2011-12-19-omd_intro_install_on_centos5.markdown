---
layout: post
theme:
  name: twitter
title: OMD系列(一)简介与安装
date: 2011-12-19
category: monitor
tags:
  - nagios
---

OMD，全称Open Monitoring Distribution，是一个围绕Nagios core构建的分布式开源监控集。在nagios基础上融合了NRPE、NSCA、check_mk、mod_gearman、pnp4nagios、nagvis、rrdcached等插件，以完成高性能的、可视化的，分权限管理的监控系统。
（我是在看mod_gearman的安装介绍时看到的，感觉这种一体式的安装很爽）
项目主页是<a href="http://omdistro.org" target="_blank">http://omdistro.org</a>，提供了rh、debian、suse和src各种安装模式。
比如在centos5上面，只需要简单的操作即可：

```bash
rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-4.noarch.rpm
#单独装graphviz是因为epel里的版本有冲突
yum install graphviz-gd.x86_64
#已经有rhel6上的版本，而5.4提供最高只到0.45，mod_gearman从0.48才加入，所以试试5.5的，发现也没问题~~
yum install --nogpgcheck http://omdistro.org/attachments/download/121/omd-0.50-rh55-25.x86_64.rpm
```

然后运行omd create monitor即可。
omd会自动在linux系统上添加一个monitor用户，然后其他操作可以在su - monitor后再继续，这样比较安全，而且可以看到的是，create的时候，还挂载了tmpfs到/omd/sites/monitor/tmp，以提供更高的性能。
切换到monitor用户后，运行omd start，即可启动。
先写到这里，慢慢看具体配置。
