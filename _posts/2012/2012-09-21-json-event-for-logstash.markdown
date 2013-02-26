---
layout: post
title: 【Logstash系列】数据格式之json-event
category: logstash
tags:
  - nginx
---

之前的各种示例中，都没有提到logstash的输入输出格式。看起来就好像logstash比Message::Passing少了decoder/encoder一样。其实logstash也有类似的设定的，这就是format。有三种选择：plain/json/json_event。默认情况下是plain。也就是我们之前的通用做法，传文本给logstash，由logstash转换成json。

logstash社区根据某些应用场景，有相关的cookbook。关于访问日志，有<http://cookbook.logstash.net/recipes/apache-json-logs/>。这是一个不错的思路！我们可以照葫芦画瓢给nginx也定义一下：
{% highlight nginx %}
     logformat json '{"@timestamp":"$time_iso8601",'
                    '"@source":"$server_addr",'
                    '"@fields":{'
                    '"client":"$remote_addr",'
                    '"size":$body_bytes_sent,'
                    '"responsetime":$request_time,'
                    '"upstreamtime":$upstream_response_time,'
                    '"oh":"$upstream_addr",'
                    '"domain":"$host",'
                    '"url":"$uri",'
                    '"status":"$status"}}';
     access_log /data/nginx/logs/access.json json;
{% endhighlight %}
这里需要注意的地方是：因为最后需要插入ES的某些field是有double/float类型。所以麻烦来了：一些端口监控工具的请求，状态码为400的，因为直接断开，所以并没有链接上upstream的服务器，其$upstream_response_time变量不存在，记录在日志里是-，这对于数值型是非法的定义。直接把带有400的日志通过file格式输入给logstash的时候，因为这个非法定义会报错，并把这行日志给丢弃掉。那么我们就无法统计400请求的数据了。

这里需要变通一下，我们知道其实所谓的Input::File就等效于tail -F ${path}${filename}(当然其实不是，模块的实际做法是在~/.sincedb里记录上次读取的位置，然后每${stat_interval}秒检查一次内容更新，每${discover_interval}秒检查一次文件描述符变更。也就是说默认其实是每秒读一次，一次几百上千行，这样效率更高)。所以我们可以自己运行tail命令，然后sed修正upstream_response_time后通过管道传递给logstash的Input::STDIN，效果是一样一样的。
新的logstash/agent.conf如下：
{% highlight ruby %}
input {
    stdin {
        type => "nginx"
        format => "json_event"
    }
} 
output {
    amqp {
        type => "nginx"
        host => "10.10.10.10"
        key  => "cdn"
        name => "logstash"
        exchange_type => "direct"
    }
}
{% endhighlight %}
运行命令如下：
{% highlight bash %}
    #!/bin/sh
      tail -F /data/nginx/logs/access.json \
    | sed 's/upstreamtime":-/upstreamtime":0/' \
    | /usr/local/logstash/bin/logstash -f /usr/local/logstash/etc/agent.conf &
{% endhighlight %}
这样可以直接省略掉昂贵的Grok操作，同时节约原本的_all/_message/_source_host等等格式的空间。
