---
layout: post
title: OMD系列(四)mod_gearman配置与运行
date: 2011-12-27
category: monitor
tags:
  - nagios
  - gearman
---

上一篇提到了shinken，这是一个完全重写过的nagios-like系统，如果想尽可能的在原有nagios知识基础上进行高性能的分布式扩展，那么可以使用mod_gearman模块。这个模块可以从github.com上直接获取使用，地址是：
<a href="https://github.com/sni/mod_gearman">https://github.com/sni/mod_gearman</a>
当然，我们这里依然是直接采用了OMD分发的方式，事实上github上也是建议直接采用omd部署，包括升级也可以直接omd update~~（因为从源代码编译的话，在nagios3.2.2版本之前还需要打个patch才能支持eventhandler，既然都得重编译，直接搞新的得了）
在github的“How it works”和“Common Scenarios”两章节里，详细的用图例说明了mod_gearman的工作原理和各种配置情形。我这里就不重复贴了。大概的说，就是可以把nagios配置检测项中的hosts/services/eventhandlers/hostgroups/servicegroups都单独成队列，然后启动多个worker有针对性的完成队列里的任务，最后也是用单独的result队列回收检测结果。
嗯，从原理上来讲，hosts/services/eventhandlers的队列，属于load balance范围，而hostgroups/servicegroups的队列，属于distribute范围。
（mod_gearman还有send_gearman程序用来load balance接收NSCA分布式监控程序的数据，这里就不说了）
<hr>
概念讲完了，现在说配置。
要启用mod_gearman，方法和上篇启用shinken一样简单，运行omd config命令，在Distribute选项中选择Mod_gearman为on，然后omd start即可。
注意，omd分发中只带了mod_gearman.so和client/worker/init脚本，你必须自己yum install gearmand安装jobserver才行。
在配置完成重启动的时候，OMD就会自动的修改nagios.cfg里的broker_module配置为：

```bash
 broker_module=.../mod_gearman.o server=localhost:4730 eventhandler=yes services=yes hosts=yes
```

同时启动1个

```bash
 /omd/sites/monitor/version/sbin/gearmand --port=4730 --pid-file=/omd/sites/monitor/tmp/run/gearmand.pid --daemon --job-retries=0 --threads=10 --log-file=/omd/sites/monitor/var/log/gearman/gearmand.log --verbose=2 --listen=localhost
```

老文章里写的gearmand默认端口都是7003，因为跟AFS冲突，所以现在的版本默认都是4730了；
同时启动3个

```bash
/omd/sites/monitor/bin/mod_gearman_worker -d --config=/omd/sites/monitor/etc/mod-gearman/worker.cfg --pidfile=/omd/sites/monitor/tmp/run/gearman_worker.pid
```

OK，现在这5个worker，会由gearmand平均分配hosts/services/eventhandlers任务。一个基础的load balance就完成了。
<hr>
下一步就是前面命令里用到了的~/etc/mod-gearman/worker.cfg配置文件了。

```bash
    debug=0
    config=/omd/sites/monitor/etc/mod-gearman/port.conf
    eventhandler=yes
    services=yes
    hosts=yes
    #hostgroups=name2,name3
    #servicegroups=name1,name2,name3
    encryption=yes
    keyfile=/omd/sites/monitor/etc/mod-gearman/secret.key
    logfile=/omd/sites/monitor/var/log/gearman/worker.log
    min-worker=3
    max-worker=50
    idle-timeout=10
    max-jobs=500
    spawn-rate=1
    fork_on_exec=no
    show_error_output=yes
    workaround_rc_25=off
```

以上是默认生成的配置文件。主要是定义最小的worker数量，最大的worker数量，最多运行的任务数量，等待超时时间，有等待任务时派生新worker的速度，是否为每个插件采用fork方式执行（这里注释写的是默认yes，但是OMD生成配置默认却是no，不知为何）；另一部分配置就是关于lb和dist的了：hosts/services/eventhandlers的yes/no控制是否lb，hostgroups/servicegroups控制dist哪些group到具体的worker上。
假设我们现在有3个servicegroup，分别叫name1/name2/name3，那么开启选项后运行omd reload命令。查看gearmand的状态如下：

```bash
    OMD[monitor]:~$ telnet 127.0.0.1 4730
    Trying 127.0.0.1...
    Connected to localhost (127.0.0.1).
    Escape character is '^]'.
    status
    check_results	0	0	1
    worker_localhost	0	0	1
    servicegroup_name1	0	0	3
    servicegroup_name2	0	0	3
    servicegroup_name3	0	0	3
    host	0	0	3
    service	0	0	3
    eventhandler	0	0	3
    dummy	0	0	5
    .
```

表示有3个worker注册在gearman的这几个任务下了。
（如果不用OMD，那么上面这些修改配置，分别启动worker指定不同配置等等动作，都要自己完成，参见github里的Installation章节From Source部份）
