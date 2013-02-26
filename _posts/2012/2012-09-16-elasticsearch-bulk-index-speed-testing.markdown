---
layout: post
title: 【Message::Passing系列】ElasticSearch的bulk_index速度测试
category: logstash
tags:
  - elasticsearch
  - perl
  - message-passing
---

连续尝试了logstash的elasticsearch/elasticsearch_http/elasticsearch_river三个putput模块，发现其index/bulk/river三种插入方式的实际运行效果速度居然没有差异。而使用perl脚本测试，单例下index不到300msg/sec，bulk接近2500msg/sec，几乎翻了10倍。

测试脚本如下：
{% highlight perl %}
    #!/usr/bin/perl -w
    use ElasticSearch;
    use JSON;
    use Time::HiRes qw/time/;
    use Data::Dumper;
    #curl -XGET 'http://localhost:9200/logstash-2012.09.14/nginx/_mapping'
    my $line = '{
        "@timestamp" : "2012-09-04T13:38:59.496888Z",
        "@tags" : [], 
        "@fields" : { 
           "reqtime" : [ 
              0.016
           ],  
           "req" : [ 
              "/fmn056/20120812/1645/tiny_r3N9_236f000036ad118d.jpg"
           ],  
           "version" : [ 
              "1.1"
           ],  
           "useragent" : [ 
              "\"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)\""
           ],  
           "port" : [ 
              "80"
           ],  
           "size" : [ 
              2360
           ],  
           "client" : [ 
              "210.56.223.176"
           ],  
           "upstream" : [ 
              "10.9.18.50"
           ],  
           "method" : [ 
              "GET"
           ],  
           "referer" : [ 
              "photo.renren.com",
              "/photo/420723228/photo-6408408309?psource=3&fromVIP=false"
           ],  
           "ZONE" : [ 
              "+0800"
           ],  
           "code" : [ 
              200 
           ],  
           "upstime" : [ 
              0.016
           ]   
        },  
        "@source_path" : "//data/nginx/logs/access.log",
        "@source" : "file://DBLYD5-32.opi.com//data/nginx/logs/access.log",
        "@message" : "[04/Sep/2012:21:38:59 +0800] 200 210.56.223.176 fmn.rrimg.com GET /fmn056/20120812/1645/tiny_r3N9_236f000036ad118d.jpg HTTP/1.1 10.9.18.50:80 0.016 0.016 2360 \"http://photo.renren.com/photo/420723228/photo-6408408309?psource=3&fromVIP=false\" \"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)\" \"-\"",
        "@source_host" : "DBLYD5-32.opi.com",
        "@type" : "nginx"
    }';
    my $hash = from_json($line);
    my $elsearch = ElasticSearch->new(
        servers      => '10.4.16.68:9200',
        transport    => 'httplite',
        max_requests => 10000,
    );
    my $begin = time;
    for ( 1 .. 1000 ) {
        my @data;
        push @data, { index => { data => $hash } } for 1 .. 20;
        $elsearch->bulk(
            index => 'logstash-test',
            type  => 'nginx',
            actions => \@data
        );
    }
    print 1000 * 20 / (time - $begin);
{% endhighlight %}
注意到这里bulk的数组是20个元素。实验证明超过20个会报出HTTP::Lite的错误(附带提示:ElasticSearch::Transport::\*的HTTPLite啊AEHTTP啊的模块都是要另外安装的)。而且在使用Logstash::Outputs::ElasticSearchHTTP时，flush_size的default值100也是无法使用的，也是改到20后才行。

ps: 不知道为什么一起发github显示不了，只好拆开了，第一篇，关于ES的index速度测试。

