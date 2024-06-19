---
layout: post
theme:
  name: twitter
title: rsyslog 的 TCP 转发性能测试
category: performance
tags:
  - rsyslog
---

做一个日志手机系统，一般有两个思路。一个是提供一个多语言 SDK 包，然后开发者只需要找到对应的 SDK 加载即可；一个是采用最通用的日志传输协议，让开发者采用现成的协议实现。在通用协议里，最常见的，就是 syslog 协议。不过 syslog 过去采用 UDP 的印象太过深入人心，rsyslog 虽然宣称在测试用达到了每秒上百万的性能，也没多少人相信。那么，到底用 syslog 协议做跨网络传输，靠不靠谱？自己用压测，来证明一下！

## 测试环境

两台测试机。其中：

A 配置为 imtcp/514，omfwd 到 B 的 514。

    module( load="imtcp" )
    input( type="imtcp" port="514" ruleset="forwardruleset" )
    Ruleset( name="forwardruleset" )
    {
        action (
            type="omfwd"
            Target="$b-server-ip"
            Port="514"
            Protocol="tcp"
            RebindInterval="5000"
            name="action_fwd"
            queue.filename="action_fwd"
            queue.size="50000"
            queue.dequeuebatchsize="1000"
            queue.maxdiskspace="5G"
            queue.discardseverity="3"
            queue.checkpointinterval="10"
            queue.type="linkedlist"
            queue.workerthreads="1"
            queue.timeoutshutdown="10"
            queue.timeoutactioncompletion="10"
            queue.timeoutenqueue="20"
            queue.timeoutworkerthreadshutdown="10"
            queue.workerthreadminimummessages="5000"
            queue.maxfilesize="500M"
            queue.saveonshutdown="on"
        )
        stop
    }

B 配置为 imtcp/514，omfile 到本机。

    module( load="imtcp" )
    input( type="imtcp" port="514" ruleset="recordruleset" )
    Ruleset( name="recordruleset" )
    {
        action( type="omfile" file="/data1/debug.log" template="defaultLogFormat" asyncWriting="on" flushOnTXEnd="off" ioBufferSize="81920k" flushInterval="5")
    }

## 测试工具

为了控制测试的速度，放弃之前压测 logstash 时候用的 logger 命令，采用 syslog-ng 项目自带的 loggen 命令。本来准备编译一下 syslog-ng，不过报错太多，实在复杂，看了一下 loggen.c 本身没啥依赖，所以决定采用最简单的办法获取 loggen 命令——下载 syslog-ng.rpm，然后直接解压压缩包！

    wget http://mirrors.zju.edu.cn/epel/5/x86_64/syslog-ng-2.1.4-9.el5.x86_64.rpm
    rpm2cpio syslog-ng-2.1.4-9.el5.x86_64.rpm  | cpio -div

*我这不能直接通过 yum install 安装，因为 syslog-ng 跟系统里已有的 rsyslog 是冲突的。*

## 测试命令

rpm 获取的 loggen 命令还不支持 `--read-data` 参数，只能自己模拟填充数据。所以测试命令如下：

    ./usr/bin/loggen -r 10000 -i -s 500 -I 600 $a-server-ip 514

意即单条长度 500 字节，每秒 10000 条的频率，持续发送 600 秒。

## 验证方式

rsyslog 有专门的 impstats 模块，输出本身运行情况的统计，可以通过如下配置开启：

    module( load="impstats" interval="60" severity="6" log.syslog="on" format="json" resetCounters="on")
    template( name="dynaFileRsyslog" type="string" string="/data1/rsyslog/impstats/%$year%/%$month%/%$day%_impstats.log" )
    if ( $syslogfacility-text == 'syslog' ) then
    {
        action  ( type="omfile"  DynaFile="dynaFileRsyslog" FileCreateMode="0600" )
        stop
    }

每 60 秒会输出 JSON 格式的统计数据，类似这样：

    2015-02-11T20:00:43.176325+08:00 localhost rsyslogd-pstats: {"name":"action_fwd queue","size":0,"enqueued":0,"full":0,"discarded.full":0,"discarded.nf":0,"maxqsize":0}

其中，enqueued 表示进入队列的条目数，size 表示暂存在内存中的条目数，discarded.full 表示队列满丢弃的条目数，discarded.nf 表示队列将满丢弃的条目数。

如果内存队列都不够用，那么 rsyslog 会记录到磁盘队列上，这时候看到类似上面的统计数据的另一条记录，区别是 `"name":"action_fwd queue[DA]"`，这个 DA 就是磁盘队列的意思。

## 测试结果

1. 每秒 5 万条的发送，可以做到毫无 size 的全部即时转发。
2. 加大 `queue.size` 到 10 倍，即时转发能力提高到 12 万条。
3. 再加大 `queue.workerthreads` 到 10，即时转发能力提高到 15 万条。
4. 单独加大 `queue.dequeuebatchsize` 到 10 倍，即时转发能力提高到 17 万条。
5. 同时加大 `queue.size` 和 `queue.dequeuebatchsize` 到 10 倍 ，即时转发能力提高到 18 万条。
6. 加大频率到 24 万，进入磁盘队列，因为这时候已经到千兆网卡瓶颈。
7. 加大模拟长度到 5000 字节，即时转发能力下降到 1 万。

最后，尽可能删除掉各种配置，以默认方式运行，发现转发能力也能达到 5 万条。查了一下源码，默认的 `queue.size` 是 1000，`queue.dequeuebatchsize` 是 16。说明在这段大小(初始测试值是默认值的 50 多倍)内，性能变化不大。

## 长期运行

测试每次只运行几分钟，还需要长期运行的考验。运行两三天的观察，同时加大到 10 倍的配置(即短期测试可以跑满网卡的配置)，在长期稳定每秒 5 万条的测试中，也会出现内存队列的 size 数。还需继续观察 size 是否累积，以及更大量的情况是否会出现磁盘队列。
