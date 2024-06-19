---
layout: post
theme:
  name: twitter
title: 不小心踩进ElasticSearch.pm模块的坑里了
category: logstash
tags:
  - elasticsearch
  - perl
---
在今天以前，我一直认为perl的ElasticSearch.pm是除了原生java库以外封装最好的。不过今天踩进一个硕大的坑里，多亏 dancer-user 邮件列表里外国友人的帮助，才算爬了出来……

# 事情是这样的

用 dancer 搭建的一个 webserver 用来提供 api 给前端图表页面。dancer 收到 ajax 请求后组装成 json 发给 ElasticSearch。因为要算百分比，无法在单次请求内完成，不然的话直接从页面上发给 ES 服务器了。

这个 webserver 是之前已经创建过的。而且作用类似，也就是说，之前已经存在一个 `DancerApp/lib/DancerApp/First.pm` 里使用了 ElasticSearch 模块。相关代码如下：

```perl
    use Dancer ':syntax';
    use ElasticSearch;
    my $elsearch = ElasticSearch->new( config->{ElasticSearch} );
```

然后给新项目创建 `DancerApp/lib/DancerApp/Second.pm` 同样使用 ElasticSearch 模块，代码原样复制。然后在 `DancerApp/lib/DancerApp.pm` 里先后加载：

```perl
    use Dancer ':syntax';
    use FindBin qw($Bin);
    use lib "$Bin/../lib";
    use DancerApp::First;
    use DancerApp::Second;
```

启动应用后访问页面。怪事出现了： _First 应用正常，Second 应用报错说 ElasticSearch 连接不上_。

仔细看报错信息，发现Second 里的 `$elsearch` 连接的不是 `config.yml` 里设定的 servers，而是模块默认的 `127.0.0.1:9200`。

更换`DancerApp/lib/DancerApp.pm` 里的加载次序，就变成了 _Second 正常，First 失败_。

试图使用下面的代码检查 `config` ，发现 config 里其他的设置都没问题，唯独和 ElasticSearch 相关的设定发生了变化：

```perl
    use Data::Dumper;
    get '/config' => sub { return Dumper config };
```

结果中 `config->{ElasticSearch}` 只剩下 `trace_calls: 0` 一条设定， `servers`、`transport`、`no_refresh` 和 `max_requests` 都消失了！

# 真相只有一个

ElasticSearch 模块在初始化的时候，会把参数传递给 `ElasticSearch::Transport` 模块做具体的操作（包括之前我很欣赏的自动选择节点服务器）。而就在这里，问题出现了：

_参数一直是以引用身份传递的，任何修改都会修改原始数据_

```perl
    my $servers = delete $params->{servers}
        || '127.0.0.1:' . $transport_class->default_port;
```

随着 `delete` 操作，悲剧就此发生了。Dancer 里的全局变量 `config->{ElasticSearch}` 中的 servers 元素就此消失……

# 善后事宜

解决办法很容易，在每个模块里初始化 ElasticSearch 实例的适合，传递一个全局 `config->{ElasticSearch}` 的_副本的引用_过去。

```perl
    my $elsearch = ElasticSearch->new( { %{ config->{ElasticSearch} } } );
```

亲爱的 David Precious 童鞋已经把这个问题上报给 ElasticSearch.pm 开发者了。或许之后会由模块内部做副本操作。目前只能自己来了。

issue 地址：<https://github.com/clintongormley/ElasticSearch.pm/issues/34>
