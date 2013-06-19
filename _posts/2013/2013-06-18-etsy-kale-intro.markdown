---
layout: post
title: 【Etsy 的 Kale 系统】简介、部署和应用
category: monitor
tags:
  - python
  - perl
  - ruby
  - elasticsearch
  - redis
  - graphite
---

监控大户 Etsy 最近有公布了一个全新的监控分析系统，叫 Kale，博客地址：<http://codeascraft.com/2013/06/11/introducing-kale/>。

目前的介绍内容比较简单。两个组件 `skyline` 和 `oculus` 之间的关系也还没搞清楚。大概上， `skyline` 是一个 python 程序，接受 `cPickle` 和 `MessagePack` 两种数据包，解压后的数据格式类似 `graphite` 接收的，然后存在 `Redis-server` 中。在 webapp 上提供一个类似 `rrdtool` 的功能，显示触发阈值线的趋势图(不触发的不会显示，自动过滤了)。

安装步骤：

{% highlight bash %}
    pip install -r requirements.txt
    apt-get install -y numpy scipy
    pip install pandas patsy statsmodels msgpack_python
    cp src/settings.py.example src/settings.py
    mkdir /var/log/skyline
    mkdir /var/run/skyline
    mkdir /var/log/redis
    # 必须用最新版的 redis-server 才能正常存储
    wget http://redis.googlecode.com/files/redis-2.6.13.tar.gz
    tar zxvf redis-2.6.13.tar.gz
    cd redis-2.6.13
    make
    ./src/redis-server ../bin/redis.conf
    cd ../src
    # 这里会启动 UDP 2024 端口接受 cpickle 包，2025 端口接受 msgpack 包
    ../bin/horizon.d start
    ../bin/analyzer.d start
    # 这里会启动 TCP 1500 端口接受 web 访问
    ../bin/webapp.d start
    # 测试是否正常
    cd ../utils
    ./seed_data.py
{% endhighlight %}

`oculus` 是一个 rack 应用，需要定时从 `skyline` 中导入数据到 `ElasticSearch` 中。同时，`oculus` 还提供了一个 `ElasticSearch` 分析器插件，可以在 ES 中完成 `FastDTW` 和 `Euclidian` 两种位移算法（用来给不同时间序列的近似度打分）。在rack 页面上，提供搜索框，你可以提交一个 metric 名称——经过测试，目前应该是采用完全匹配的方式搜索——然后展示这个 metric 的图形，以及按照 score 打分排序的近似时间序列。

* 欧几里德算法原理：根据两点的坐标系计算直线距离；
* 动态时间归整原理：将时间序列进行延伸或者缩短，然后再计算。
<http://www.cnblogs.com/kemaswill/archive/2013/04/18/3028610.html>

安装步骤：

{% highlight bash %}
    # 只能用 0.20.5 版，0.90 版目前不支持
    wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.5.tar.gz
    tar zxvf elasticsearch-0.20.5.tar.gz
    mv elasticsearch-0.20.5 /opt/elasticsearch
    # 编译插件
    cp -r resources/elasticsearch-oculus-plugin /opt/elasticsearch/
    pushd /opt/elasticsearch/elasticsearch-oculus-plugin
    rake build
    cp OculusPlugins.jar /opt/elasticsearch/lib/OculusPlugins.jar
    # 加载分析器和脚本
    cat >>/opt/elasticsearch/config/elasticsearch.yml<<EOF
    script.native:
      oculus_euclidian.type: com.etsy.oculus.tsscorers.EuclidianScriptFactory
      oculus_dtw.type: com.etsy.oculus.tsscorers.DTWScriptFactory
    EOF
    # 启动
    /opt/elasticsearch/bin/elasticsearch
    
    popd
    bundle install
    mkdir /var/run/oculus
    mkdir /var/log/oculus
    # 启动 worker 进程，这是import.rb 和 ES 交流的渠道
    rake resque:start_workers
    # 编辑 config/config.yml，注意里面ES一定要提供两台，哪怕写一个127.0.0.1一个localhost，后面 import 会验证数目
    vi config/config.yml
    # 从 skyline 导入数据
    ./scripts/import.rb
    echo '*/2 * * * * ~/oculus/scripts/import.rb &> /var/log/oculus/import.log' >> cron.list
    crontab -u root cron.list
    # 启动web
    thin start
    # 默认用户密码都是admin，需要先点击初始化
    gnome-open localhost:3000/admin
{% endhighlight %}

`oculus` 的测试我是做出来了。如图：

![oculus](/images/uploads/oculus.png)

这个数据我是通过 perl 生成的随机数，所以也没什么近似队列了。展示一下脚本，这样说明我们可以通过其他脚本扩展 Kale 系统的用途。

{% highlight perl %}
    #!/usr/bin/env perl
    use strict;
    use warnings;
    use Data::MessagePack;
    use AnyEvent::Handle::UDP;
    
    my $mp = Data::MessagePack->new->utf8->prefer_integer;
    
    my $cv   = AnyEvent->condvar;
    my $sock = AnyEvent::Handle::UDP->new(
        connect   => [ '127.0.0.1', '2025' ],
        on_recv   => sub { },
        autoflush => 1,
    );
    
    my $timer = AnyEvent->timer(
        after    => 0,
        interval => 5,
        cb       => sub {
            print "send...\n";
            my $data = [ 'localhost.loadavg', [ time(), rand() * 2 ] ];
            my $packed = $mp->pack($data);
            $sock->push_send("$packed");
        },
    );
    
    $cv->recv;
{% endhighlight %}

从源码中，看到还有 `ganglia_to_skyline.rb` 脚本。目前看，`Kale` 应该是想着用 `skyline` 代替 `graphite-web`，得用 `redis` 来代替 `graphite-whisper`，不过我觉得似乎意义不是很大，还不如直接把数据存入 `ElasticSearch`，形成一套类似 `openTSDB` 的，但是完全基于 ES 的高扩展分布式方案。
