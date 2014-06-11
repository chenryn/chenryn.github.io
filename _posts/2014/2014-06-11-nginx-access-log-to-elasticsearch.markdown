---
layout: post
title: 用 LEK 组合处理 Nginx 访问日志
category: logstash
tags:
  - elasticsearch
  - perl
  - syslog
  - anyevent
---

Tengine 支持通过 syslog 方式发送日志（现在 Nginx 官方也支持了），所以可以通过 syslog 发送访问日志到 logstash 平台上，这种做法相对来说对线上服务器影响最小。最近折腾这件事情，一路碰到几个难点，把解决和优化思路记录一下。

## 少用 Grok

感谢群里 @wood 童鞋提供的信息，Grok 在高压力情况下确实比较容易率先成为瓶颈。所以在日志格式可控的情况下，最好可以想办法跳过使用 Grok 的环节。在早先的 cookbook 里，就有通过自定义 LogFormat 成 JSON 样式的做法。我前年博客上也写过 nginx 上如此做的示例：<http://chenlinux.com/2012/09/21/json-event-for-logstash/index.html>。

不过这次并没有采用这种方式，而是定义日志格式成下面的样子，因为这种分割线方式对 Hive 平台同样是友好的。

    log_format syslog '$remote_addr|$host|$request_uri|$status|$request_time|$body_bytes_sent|'
                      '$upstream_addr|$upstream_status|$upstream_response_time|'
                      '$http_referrer|$http_add_x_forwarded_for|$http_user_agent';
    access_log syslog:user:info:10.4.16.68:29125:tengine syslog ratio=0.1;

那么不用 Grok 怎么做呢？这里有一个很炫酷的写法。下面是 logstash 配置里 filter 段的实例：

    filter {
        ruby {
            remove_field => ['@version', 'priority', 'timestamp', 'logsource', 'severity', 'severity_label', 'facility', 'facility_label', 'pid','message']
            init => "@kname = ['client','servername','url','status','time','size','upstream','upstreamstatus','upstreamtime','referer','xff','useragent']"
            code => "event.append(Hash[@kname.zip(event['message'].split('|'))])"
        }
        mutate {
            convert => ["size", "integer", "time", "float", "upstreamtime", "float"]
        }
        geoip {
            source => "client"
            fields => ["country_name", "region_name", "city_name", "real_region_name", "latitude", "longitude"]
            remove_field => [ "[geoip][longitude]", "[geoip][latitude]" ]
        }
    }

而要达到跟这段 ruby+mutate 效果一致的 grok ，写法是这样的：

    filter {
        grok {
            match => ["message", "%{IPORHOST:client}\|%{HOST:servername}\|%{URIPATHPARAM:url}\|%{NUMBER:status}\|(?:%{NUMBER:time:int}|-)\|(?:%{NUMBER:size}|-)\|(?:%{HOSTPORT:upstream}|-)\|(?:%{NUMBER:upstreamstatus}|-)\|(?:%{NUMBER:upstreamtime:int}|-)\|(?:%{URI:referer}|-)\|%{GREEDYDATA:xff}\|%{GREEDYDATA:useragent}"]
            remove_field => ['@version', 'priority', 'timestamp', 'logsource', 'severity', 'severity_label', 'facility', 'facility_label', 'pid','message']
        }
    }

# syslog 瓶颈

运行起来以后，通过 Kibana 看到的全网 tengine 带宽只有 60 MBps左右，这个结果跟通过 NgxAccounting 统计输出的结果差距太大了。明显是有问题。

首先怀疑不会是 nginx.conf 通过 Puppet 下发重启的时候有问题吧？实际当然没有。

这时候运行 `netstat -pln | grep 29125` 命令，发现 `Recv-Q` 已经达到了 228096，并且一致维持在这个数没有变化。

由于之前对 ES 写入速度没太大信心，所以这时候的反应就是去查看 ES 服务器的状态，结果其实服务器 idle% 在 80% 以上，各种空闲，Kibana 上搜索反应也非常快。通过 top 命令看具体的线程情况，logstash 的 output/elasticsearch worker 本身占用资源就很少。包括后来实际也尝试了加大 output 的 workers 数量，加大 bin/logstash -w 的 filter worker 数量，其实都没用。

那么只能是 input/syslog 就没能收进来了。

之前写 filter 的时候，开过 -vv 模式，所以注意到过 input/syslog 里是利用 Logstash::Filter::Grok 来判定切割 syslog 内容的。按照前一节的说法，那确实可能是在收 syslog 的时候性能跟不上啊？

于是去翻了一下 Logstash::Input::Syslog 的代码，主体逻辑很简单，就是 `Thread.new { UDPSocket.new }` 这样。也就是说是一个单线程监听 UDP 端口！

然后我又下载了同为 Ruby 写的日志收集框架 fluentd 的 syslog 插件看看源代码，fluent-plugin-syslog 里，用的是 Cool.io 库作 UDP 异步处理。好吧，其实在此之前我只知道 EventMachine 库。。。不过由于 Logstash 是 JRuby 平台，又不清楚其 event 代码(以前基本只是看各种 plugin 的代码就够了)，担心这么把 em 加上去会不会不太好。所以在摸清 logstash 代码之前，先用自己最熟悉的手段，搞定这个问题：

**用 Perl 的高性能 EV 库解决**

前年我同样提到过 Perl 也有仿照 Logstash 写的框架叫 Message::Passing，这个框架就是用 AnyEvent 和 Moo 写的，性能绝对没问题。不过各种插件和文档比较潦草，要想兼容现在 logstash 1.4 的 schema 比较费劲。所以，最后我选择了自己根据 tengine 日志的情况单独写一个脚本，结果如下：

<script src="https://gist.github.com/chenryn/7c922ac424324ee0d695.js"></script>

80 行左右的代码，从 input 到 output 都是 anyevent 驱动。( Search::Elasticsearch::Async 默认是基于 AnyEvent::HTTP 的，不过用 Promises 模块做了封装，所以写起来好像看不太出来～)

最终到 elasticsearch 里的数据结构跟 logstash 一模一样，之前配置好的 Kibana 样式完全不需要变动。而实际运行起来以后，Recv-Q 虽然不是一直保持在 0，但是偶然累积的队列也肯定会在几秒钟内被读取处理完毕。完全达到了效果。Kibana 上，带宽图回复到了跟 NgxAccounting 统计结果一样的 300 MBps 。成功！

![](/images/uploads/ngx-syslog-flow-diff.png)
