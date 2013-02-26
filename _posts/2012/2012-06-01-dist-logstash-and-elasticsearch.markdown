---
layout: post
title: 【Logstash系列】用rabbitmq和elasticsearch搭建分布式日志收集存储系统
category: logstash
date: 2012-06-01
tags:
  - rabbitmq
  - elasticsearch
---

上上篇讲到怎样用MRI的ruby在客户端收集日志。今天主要注意服务器端，考虑grok、elastic、web这几个功能在JRuby上才好。所以服务器端可以再开一个JRuby的进程。

* 首先安装RabbitMQ的过程

最简单的办法，采用epel的yum，或者apt安装。其次简单的办法，从rabbitmq上下载bin的tar.gz。   
这里需要注意一下，rabbitmq-server启动的时候，默认node启动在rabbit@${hostname}上。而且这个hostname不是fqdn的，是第一个主机名。比方说你的hostname是MyHome-1.mydomain.com.，那node就是rabbit@MyHome-1。这个时候很容易报Connect MyHome-1 timeout。所以/etc/hosts一定要写好。    
rabbitmq-server起来之后，可以用rabbitmyctl来具体的创建user啊，vhost啊之类的东西，作为测试，我们就直接使用默认的guest用户和/了。

* 然后安装elasticsearch的过程

这一步在logstash的docs里讲的很清楚了，就是下载tar.gz，解压然后java运行起来即可：    
{% highlight bash %}
ES_PACKAGE=elasticsearch-0.18.7.zip
ES_DIR=${ES_PACKAGE%%.zip}
SITE=https://github.com/downloads/elasticsearch/elasticsearch
if [ ! -d "$ES_DIR" ] ; then
  wget --no-check-certificate $SITE/$ES_PACKAGE
  unzip $ES_PACKAGE
fi
{% endhighlight %}

* 部署一个logstash的采集节点

和上篇所述一样，传输一个删减版的Gemfile到采集节点。然后使用bundle安装这些模块：    
{% highlight bash %}
mkdir -p /usr/local/logstash/etc /usr/local/logstash/bin /usr/local/logstash/lib
scp ${logstashmaster}:/usr/local/logstash/Gemfile /usr/local/logstash/
scp -rf ${logstashmaster}:/usr/local/logstash/lib/* /usr/local/logstash/lib/
scp ${logstashmaster}:/usr/local/logstash/bin/logstash /usr/local/logstash/bin/
gem install bundler
cd /usr/local/logstash/
bundle install
{% endhighlight %}
然后编写一个使用rabbitmq的配置文件：
{% highlight ruby %}
input {
  file {
    type => "syslog"
    path => ["/var/log/syslog.log", "/var/log/messages" ]
  } 
}

output {
  amqp {
    host => "MyHome-1"
    exchange_type => "fanout"
    name => "rawlogs"
  }
}
{% endhighlight %}
OK，用ruby /usr/local/logstash/bin/logstash agent -f /usr/local/logstash/etc/agent.conf启动即可。

* 部署一个logstash的汇聚节点

这一步因为用到的模块大多是JRuby的，所以可以直接使用jar包的方式简单搞定。
编写一个使用rabbitmq和elasticsearch的配置文件：
{% highlight ruby %}
input {
  amqp {
    type => "syslog"
    host => "MyHome-1"
    exchange => "rawlogs"
    name => "rawlogs_consumer"
  }
}

filter {
  grok {
    type => "syslog"
    pattern => "%{SYSLOG}"
  }
}
output {
  elasticsearch { }

}
{% endhighlight %}
这里比较讨厌的还是rabbitmq的部分。假如前面的步骤rabbitmq-server压根启动失败了，这里amqp不会返回报错说连接失败或者连接node超时什么的，而是说你试图连接一个私有的被锁定的队列……

* 部署一个logstash的展示节点

这个节点就没必要再单开一台了，就用上面的jar包再启动一个web即可：java -jar logstash-1.1.0-monolithic.jar agent -f server.conf -- web --backend 'elasticsearch:///?local'

* 测试

现在可以打开浏览器访问web查看了。很简单的页面，顶上一个搜索栏，中间一个按时间轴显示的柱状图，下面是具体的日志记录。点具体的某条日志，会有浮框显示该条记录的详细信息(host/date/event/message等)

下一步研究grok正则匹配的编写，然后stated实时绘图，lucene查询语法。
