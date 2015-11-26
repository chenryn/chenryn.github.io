---
layout: post
title: LogStash::Inputs::Syslog 性能测试与优化
date: 2014-10-18 00:01:00
category: logstash
tags:
  - syslog
  - ruby
  - netty
---

最近因为项目需要，必须想办法提高 logstash indexer 接收 rsyslog 转发数据的性能。首先，就是要了解 logstash 到底能收多快？

之前用 libev 库写过类似功能的程序，所以一开始也是打算找个能在 JRuby 上运行的 netty 封装。找到了 [foxbat](https://github.com/m0wfo/foxbat) 库，不过最后发现效果跟官方的标准 socket 实现差不多。（这部分另篇讲述）

后来又发现另一个库：[jruby-netty](https://github.com/jordansissel/experiments/tree/master/ruby/jruby-netty/syslog-server)，注意到这个作者就是 logstash 作者 jordansissel！

当然，最终并不是用上这个项目的代码来改写 logstash，而是从这里面学到了如何方便的进行 syslog server 性能压测。测试方式：

    yes "<44>May 19 18:30:17 snack jls: foo bar 32" | nc localhost 3000

或者

    loggen -r 500000 -iS -s 120 -I 50  localhost 3000
    
loggen 是 syslog-ng 带的工具，还得另外安装。而上面第一行的方式，这个 `yes` 用的真是绝妙！

就用这个测试方法，最终发现单机上 LogStash::Inputs::Syslog 的每秒处理能力只有 700 条：

    input {
        syslog {
            port => 3000
        }
    }
    output {
        stdout {
            codec => dots
        }
    }
    
logstash 配置文件见上。然后测试启动命令如下：

    ./bin/logstash -f syslog.conf | pv -abt > /dev/null

*注意，centos 上的 pv 命令可能还没有 `-a` 参数。*

为了逐一排除性能瓶颈。我依次注释掉了 `lib/logstash/inputs/syslog.rb` 中 `@date_filters.filter(event)` 和 `@grok_filters.filter(event)` 两段，并重新运行上次的测试。结果发现：

* TCPServer 接收的性能是每秒 50k 条
* TCPServer 接收并完成 grok filter 的性能是每秒 5k 条
* TCPServer 接收并完成 grok 和 date filter 的性能是每秒 700 条

性能成几何级的下降！

而另外通过 `input { generator { count => 3000000 } }` 测试可以发现，logstash 本身空数据流转的性能也不过就是每秒钟几万条。所以，优化点就在后面的 filter 上。

*注：空数据流转的测试采用 inputs/generator 插件*

LogStash::Inputs::Syslog 中，TCPServer 对每个 client 单独开一个 Thread，但是这个 Thread 内要顺序完成 `@codec.decode`，`@grok_filter.filter` 和 `@date_filter.filter` 三大步骤后，才算完成。而我们都知道：Logstash 配置中 filter 阶段的插件是可以多线程完成的。所以，解决办法就来了：

    input {
        tcp {
            port => 3000
        }
    }
    filter {
        grok {
            overwrite => "message"
            match => ["message", "<\d+>%{SYSLOGLINE}"]
        }
        date {
            locale => "en"
            match => ["timestamp", "MMM dd HH:mm:ss", "MMM  d HH:mm:ss"]
        }
    }
    output {
        stdout {
            codec => dots
        }
    }
  
然后重新测试，发现性能提高到了每秒 4.5k。再用下面命令运行测试：
  
      ./bin/logstash -f syslog.conf -w 20 | pv -bt > /dev/null
      
发现性能提高到了每秒 30 k 条！

此外，还陆续完成了另外一些测试。

比如：

* outputs/elasticsearch 的 protocol 使用 node 还是 http 的问题。测试在单台环境下，node 只有 5k 的 indexing 速度，而 http 有7k。
* 在 inputs/file 的前提下，outputs/stdout{dots} 比 outputs/elasticsearch{http} 处理速度快一倍，即有 15k。
* 下载了 heka 的二进制包，通过下面配置测试其接受 syslog 输入，并以 logstash 的 schema 输出到文件的性能。结果是每秒 30k，跟之前优化后的 logstash 基本一致。

```ini
[hekad]
maxprocs = 48

[TcpInput]
address = ":5140"
parser_type = "token"
decoder = "RsyslogDecoder"

[RsyslogDecoder]
type = "SandboxDecoder"
filename = "lua_decoders/rsyslog.lua"

[RsyslogDecoder.config]
type = "mweibo"
template = '<%pri%>%TIMESTAMP% %HOSTNAME% %syslogtag%%msg:::sp-if-no-1st-sp%%msg:::drop-last-lf%\n'
tz = "Asia/Shanghai"

[ESLogstashV0Encoder]
es_index_from_timestamp = true
fields = ["Timestamp", "Payload", "Hostname", "Fields"]
type_name = "%{Type}"

# [ElasticSearchOutput]
# message_matcher = "Type == 'nginx.access'"
# server = "http://10.13.57.35:9200"
# encoder = "ESLogstashV0Encoder"
# flush_interval = 50
# flush_count = 5000

[counter_output]
type = "FileOutput"
path = "/tmp/debug.log"
message_matcher = "TRUE"
encoder = "ESLogstashV0Encoder"
```

heka 文档称 maxprocs 设置为 cpu 数的两倍。不过实际测试中，不配置跟配置总共也就差一倍的性能。
