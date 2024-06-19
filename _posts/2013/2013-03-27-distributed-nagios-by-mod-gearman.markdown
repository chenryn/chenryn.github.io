---
layout: post
theme:
  name: twitter
title: 用 Mod_Gearman 实现 Nagios 分布式
category: monitor
tags:
  - nagios
  - gearman
---

在 2011 年年底，我曾经连续写过四篇介绍 OMD 的文章。

1. <http://chenlinux.com/2011/12/19/omd_intro_install_on_centos5/>
2. <http://chenlinux.com/2011/12/27/conf_run_mod_gearman/>
3. <http://chenlinux.com/2011/12/20/omd_configurations_basic/>
4. <http://chenlinux.com/2011/12/20/shinken_discovery_runner/>

不过之前都停留在代码观摩和安装文档的阶段。这几天刚好有点需求，真正测试了一下如何利用 mod\_gearman 实现 分布式的 Nagios 监测集群。

OMD 的安装一如既往的简单，尤其是作为中控端，不需要讲究太多通用性，可以选择使用 ubuntu 系统，直接通过 deb 安装：

```bash
wget http://omdistro.org/attachments/download/197/omd-0.56_0.wheezy_i386.deb
dpkg -i omd-0.56_0.wheezy_i386.deb
omd create cdn-monitor
su - cdn-monitor
omd start
```

这就已经启动了。

不过要使用 mod\_gearman 的话，还需要通过 `omd config` 界面开启。

默认开启之后，是运行在本机多 worker 的 Load Balance 状态下。我们现在要做的是把worker拆分到其他机房去变成 Distributed 状态。

![distributed](/images/uploads/sample_distributed.png)

图上已经列出 server 和 worker 的主要配置不同。我们只需要照着这样改就可以了。

不过在作为纯 worker 端的机房服务器上，我们没有必要安装完整的 OMD 了，这厮安装包都有100MB大……

<http://mod-gearman.org/download/v1.4.2/> 上提供了 mod\_gearman 的独立安装包，我们只需要根据服务器发行版选择下载就可以，这里以 CentOS6 为例，相信现在这个也应该是服务器的主流。

```bash
wget http://mod-gearman.org/download/v1.4.2/rhel6/x86_64/gearmand-0.25-1.rhel6.x86_64.rpm
wget http://mod-gearman.org/download/v1.4.2/rhel6/x86_64/mod_gearman-1.4.2-1.e.rhel6.x86_64.rpm
rpm -ivh gearmand-0.25-1.rhel6.x86_64.rpm mod_gearman-1.4.2-1.e.rhel6.x86_64.rpm
```

除了图中列出的几行关键配置以外，还有两个地方是需要修改的：

### gearmand 的监听

OMD 安装的 gearmand 默认是监听在 127.0.0.1 上的，需要修改`/omd/sites/cdn-monitor/etc/mod-gearman/port.conf` 文件变成可以被其他机器访问的 IP 地址并重启。

同样 分布式的 `/etc/mod_gearman/mod_gearman_worker.conf` 里，也需要修改 server 配置并重启服务。

### encryption 配置

OMD 默认启用 encryption 并且会在 `/omd/sites/cdn/etc/mod-gearman/` 下生成 `secret.key` 文件。

但是 `mod_gearman` 默认开启 encryption ，却不可能知道中控端的密码，所以默认是在配置文件中指定的 `key=should_be_changed`。这里我们需要修改一致：

```bash
scp nagios:/omd/sites/cdn/etc/mod-gearman/secret.key /etc/mod_gearman/
sed 's!#keyfile.*!keyfile=/etc/mod_gearman/secret.key!' /etc/mod_gearman/mod_gearman_worker.conf
service mod_gearman_worker restart
```

事情还没完。这时候你会在 webUI 上看到分配给这个 worker 的检测全部报错，退出码 127。具体内容是："/omd/sites/cdn-monitor/lib/nagios/plugins/check_http do not exists"之类的话。

因为，在 OMD 上，commands.cfg 上，配置的 `$USER1$/check_http` 替换为具体路径后，直接 `add_task` 到 gearmand 里，所以 worker 上收到 command 并执行也就是这样的了。目前还没有发现可以在 worker 端替换 commands 字符串的简单办法。所以，我们还得自己创建一个软链接：

```bash
mkdir -p /omd/sites/cdn-monitor/lib/nagios/
yum install -y nagios-plugins-all --enablerepo=epel
ln -s /usr/lib64/nagios/plugins /omd/sites/cdn-monitor/lib/nagios/plugins
```

OK，现在这个机房(即nagios配置中的hostgroup)的监测任务，就都分发给本机房的 worker 来进行了。比如 `check_http` 任务，可以看到原先跨机房访问带来的几十毫秒的延时，都变成了一两毫秒。
