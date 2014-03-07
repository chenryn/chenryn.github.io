---
layout: post
title: 转换 diagramo 绘制的拓扑图成 fig.yml 格式
category: docker
tags:
  - perl
  - php
  - docker
---

前几天在微博上跟 [@易度-潘俊勇](http://weibo.com/panjunyong) 在评论里提到，已经有了 [Fig](http://orchardup.github.io/fig/) 工具可以通过写一个 `fig.yml` 来快速定义主机上各 docker 容器的配置和角色。如果再进一步，可以通过绘图的方式，直接拖拽生成整个 docker 集群，那就更好了。

> 这个FIG挺有趣的，我自己写了一个类似的脚本。
> 不过我觉得终极的解决方案是画个关系图，就配置好了。
> 这个图的存储形式应该就是这个FIG，或者FIG可以转换为图。然后又可以转换为systemd的配置文件。

画关系图，桌面上肯定是 visio，visio保存成 XML 后分析 XML 就可以了。不过 visio 本身也算笨重的了，如果可以在浏览器中完成这个工作，才算够 cool！

网页上的 visio 已经有些产品，不过有名的几个都是有限免费试用的。好在找到一个叫做 [diagramo](http://diagramo.com) 的项目，虽然提供的元素图表不多，但是也够用了。

下载源码包，在 LAMP/LEMP 环境下就直接跑起来，首次访问会要求注册一个用户名。环境配置中有一点必须重点点出来的：

*Apache/Nginx 上配置的 `server_name` 必须跟你浏览器访问的完全一致*

我曾经因为测试，所以写了个 localhost 做 server_name，然后用服务器 IP 地址来访问页面，结果在绘图完成保存的时候会出错！*因为这是一个 HTML5 项目，保存这步是调用的 `canvas.toDataURL()` 函数，这个函数有强制性安全限定，以保证调用这个函数的页面，跟生成的图片路径必须是同一个域名！否则跨域抓图太方便了。*

(写到这里感慨一下，chrome的调试工具不会用，这问题最后还是在 IE开发者工具的帮助下发现的 ==！)

然后就可以画关系图了，比如下图这样：

![sample of diagramo](/images/uploads/dia.png)

点击保存后，就会在服务器上的 `$document_root/editor/data/diagrams` 目录下生成对应的 `.dia` 和 `.png` 文件。这个所谓的 `.dia` 文件，其实内容就是 JSON数据。下面我们只要抽取 JSON 里有关的数据就可以了：

{% highlight perl %}
use File::Slurp;
use JSON;
use YAML;
use Test::Deep::NoTest;
use 5.010;
use warnings;
use strict;

my $hash = from_json( read_file( $ARGV[0] ) );

my $hostinfo;
for my $host ( @{ $hash->{s}->{figures} } ) {
    $hostinfo->{ $host->{id} } = Load( $host->{primitives}->[1]->{str} );
}

for my $conn ( @{ $hash->{m}->{connectors} } ) {
    my $connid = $conn->{id};
    my $start  = $conn->{turningPoints}->[0];
    my $end    = $conn->{turningPoints}->[1];
    if ( $conn->{endStyle} eq 'Normal' and $conn->{startStyle} eq 'Arrow' ) {
        ( $start, $end ) = ( $end, $start );
    }
    my ( $startid, $endid );
    for my $point ( @{ $hash->{m}->{connectionPoints} } ) {
        if (    eq_deeply( $point->{point}, $start )
            and $point->{parentId} != $connid
            and exists $hostinfo->{ $point->{parentId} } )
        {
            $startid = $point->{parentId};
        }
        elsif ( eq_deeply( $point->{point}, $end )
            and $point->{parentId} != $connid
            and exists $hostinfo->{ $point->{parentId} } )
        {
            $endid = $point->{parentId};
        }
    }
    my ($startname) = keys %{ $hostinfo->{$startid} };
    my ($endname) = keys %{ $hostinfo->{$endid} };
    push @{ $hostinfo->{$startid}->{$startname}->{link} }, $endname;
}

say Dump { map { my ($k) = keys $_; $k => $_->{$y} } values $hostinfo};
{% endhighlight %}

生成的 `fig.yml` 如下：

{% highlight yaml %}
---
Haproxy:
  link:
   - Serf
Nginx1:
  link:
   - Serf
Serf:
Nginx2:
  link:
   - Serf
MySQL:
  link:
   - Serf
{% endhighlight %}

只是根据关系图生成了 link，其他配置都在图里的 Text 里照样写 yaml 格式，会自动带入。当然，示例另一个意思是：大家尽量都只 link 像 serf/etcd 这样的服务自动发现服务器。在 docker 层面就简洁明了。
