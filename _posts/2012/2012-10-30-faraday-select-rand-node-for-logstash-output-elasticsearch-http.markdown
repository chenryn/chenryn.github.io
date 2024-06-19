---
layout: post
theme:
  name: twitter
title: 【Logstash系列】Outputs::ElasticsearchHTTP自动获取随机node
category: logstash
tags:
  - ruby
  - elasticsearch
---
今天在ES群中和medcl请教了一下index的性能问题。基本上在bulk的基础上，还有几点是可以做的。当然medcl说的是正常的全文索引的场景：

* 不用http协议，直接走tcp层，维护一个pool发bulk；
* 多台node的情况下，在bulk前先设置replica为0；bulk完成后再调整replica；
* 因为es会自动路由，所以index请求可以分散开直接发给多个node。

总之，就是减少集群内部的网络传输。

介于logstash的应用是一直持续往es写数据的，所以replica调整这招用不上，顶多加大refresh时间而已。所以可以动手的地方主要就是第三条了。

正好去翻了一下perl的Elasticsearch.pm的POD。发现原来perl模块本色默认就是这么做的。new的时候定义的server，是用来发送请求获取集群所有alive的nodes。然后会从这个nodes列表里选择(随机)一个创建真正的链接返回。获取nodes的API如下：
```bash
curl http://192.168.1.33:9200/_cluster/nodes?pretty=1
{
  "ok" : true,
  "cluster_name" : "logstash",
  "nodes" : {
    "he6ipuA3SDeNmOQYIr-bjg" : {
      "name" : "Afari, Jamal",
      "transport_address" : "inet[/192.168.1.33:9300]",
      "hostname" : "ES-33.domain.com",
      "http_address" : "inet[/192.168.1.33:9200]"
    },
    "WXK68VX0ThmNnozq0uioQw" : {
      "name" : "Harker, Quincy",
      "transport_address" : "inet[/192.168.1.68:9300]",
      "hostname" : "ES-68.domain.com",
      "http_address" : "inet[/192.168.1.68:9200]"
    }
  }
}
```
这样显然可以在cluster较大的时候分担index的压力(search的时候压力在集群本身的cpu上)。我打算给我的pure-ruby branch里的faraday版的Logstash::Outputs::ElasticsearchHTTP也加上这个功能。
<hr />
大致简单实现如下：
```ruby
  def select_rand_host
    require "json"
    begin
      response = @agent.get '/_cluster/nodes'
      nodelist = JSON.parse(response.body)['nodes'].values
      livenode = nodelist[rand(nodelist.length)]["http_address"].split(/\[|\]/)[1]
      @agent = Faraday.new(:url => "http:/#{livenode}") do |faraday|
        faraday.use Faraday::Adapter::EMHttp
      end
    end
  end
```
然后在`def register`里和`def flush`的`retry`前面都加上`select_rand_host()`就好了。当然比起perl的ElasticSearch::Transport里各种检查各种排除，我这个还是简单多了……
另，在Ruby1.9里从数组返回随机元素可以直接调用`.sample`，真赞。不过谁让我都是1.8.7的版本呢……

__2012 年 12 月 30 日附注：__

之后我在 maillist 里联系了 logstash 的作者。不过作者表示：第一，需要自选 node 功能的，建议使用 output/elasticsearch 因为这个是用的 java 客户端，直接会把自己作为一个 node 加入 ES 的 cluster。第二，ruby 的 http 模块他都不喜欢，所以全部项目里的相关部分他都只用自己写的 ftw 模块 ==!

__2013 年 02 月 26 日附注：__

最新版的 Logstash::Outputs::ElasticSearchHTTP 已经加入随机选择 node 功能。是其他网友在 ftw 模块基础上添加的。

