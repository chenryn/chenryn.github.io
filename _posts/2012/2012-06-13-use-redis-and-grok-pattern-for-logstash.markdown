---
layout: post
title: 【Logstash系列】使用Redis并自定义Grok匹配
category: logstash
date: 2012-06-13
tags:
  - redis
---
之前提到，用RabbitMQ作为消息队列。但是这个东西实在太过高精尖，不懂erlang不会调优的情况下，很容易挂掉——基本上我这里试验结果跑不了半小时日志传输就断了。所以改用简单易行的redis来干这个活。

之前的lib里，有inputs/redis.rb和outputs/redis.rb两个库，不过output有依赖，所以要先gem安装redis库，可以修改Gemfile，取消掉相关行的注释，搜redis即可。

然后修改agent.conf：

{% highlight ruby %}
input {
  file {
    type => "nginx"
    path => ["/var/log/nginx/access.log" ]
  }
}

output {
  redis {
    host => "MyHome-1.domain.com"
    data_type => "channel"
    key => "nginx"
    type => "nginx"
  }
}
{% endhighlight %}

启动方式还是一样。

接着修改server.conf:

{% highlight ruby %}
input {
  redis {
    host => "MyHome-1.domain.com"
    data_type => "channel"
    type => "nginx"
    key => "nginx"
  }
}

filter {
  grok {
    type => "nginx"
    pattern => "%{NGINXACCESS}"
    patterns_dir => ["/usr/local/logstash/etc/patterns"]
  }
}
output {
  elasticsearch { }

}
{% endhighlight %}

然后创建Grok的patterns目录，主要就是github上clone下来的那个咯~在目录下新建一个叫nginx的文件，内容如下：

{% highlight ruby %}
NGINXURI %{URIPATH}(?:%{URIPARAM})*
NGINXACCESS \[%{HTTPDATE}\] %{NUMBER:code} %{IP:client} %{HOSTNAME} %{WORD:method} %{NGINXURI:req} %{URIPROTO}/%{NUMBER:version} %{IP:upstream}(:%{POSINT:port})? %{NUMBER:upstime} %{NUMBER:reqtime} %{NUMBER:size} "(%{URIPROTO}://%{HOST:referer}%{NGINXURI:referer}|-)" %{QS:useragent} "(%{IP:x_forwarder_for}|-)"
{% endhighlight %}

Grok正则的编写，可以参考[wiki](https://github.com/logstash/logstash/wiki/Testing-your-Grok-patterns-%28--logstash-1.1.0-and-above-%29)进行测试。

也可以不写配置文件，直接用--grok-patterns-path参数启动即可。

ps: 考察了一下statsd，发现它也要另存一份数据，放弃掉。转研究Kibana界面和Elasticsearch的分布式。

