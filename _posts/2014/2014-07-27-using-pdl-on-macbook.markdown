---
layout: post
title: 在 MacBook 上使用 PDL 绘图
category: perl
tags:
  - zabbix
  - pdl
  - python
  - numpy
  - macbook
---

之前在 Linux 服务器上使用 PDL，主要是一些矩阵函数，这次准备在个人电脑上使用 PDL，尤其是本身的绘图功能，其一目的就是导出 zabbix 中存储的监控数据，通过 PDL 绘图观察其季节性分布情况。

不过在使用的时候，发现在 MacBook 上跑 PDL 还是有点上手难度的。和 pylab 不同，PDL 是使用了 X11 的，而 MacBook 最新的版本里，X11 已经不再是自带的了。所以需要单独去下载 [XQuartz](https://www.macupdate.com/app/mac/26593/xquartz) 安装包来提供 X11 支持。

安装好了 XQuartz 以后，再安装 PDL::Graphics:: 名字空间下的几个模块就好办了。

* PDL::Graphics::Simple
* PDL::Graphics::Gnuplot
* PDL::Graphics::PGPLOT
* PDL::Graphics::Prima

另外还有 PDL::Graphics::PLplot 等，不过通过 `port install plplot` 安装的 plplot 没有 header 文件，所以 PDL::Graphics::PLplot 是安装不上的，既然前面已经有了不少，这里也就不再追求自己下载 plplot 源代码来安装了。

PDL::Graphics::Simple 是 《PDL Book》开篇第一个示例就使用的模块，其实际就是按顺序尝试加载 `::Gnuplot`、`::PGPLOT`、`::PLplot` 和 `::Prima`。所以，保证有一个可用就好了。

不过在我的 air 上实际的效果来看，perldl 命令在使用 子进程跟 gnuplot 交互的时候**非常非常非常的慢！**

好了，现在就可以运行程序了：

{% highlight perl %}
#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature ':5.16';
use Path::Tiny;
use YAML;
use PDL;
use PDL::Graphics::PGPLOT;
use Zabbix2::API;

my $config = Load( path('config.yml')->slurp );
my $zbconf = $config->{'zabbix'};
my $zabbix =
  Zabbix2::API->new(
    server => "http://$zbconf->{'addr'}/zabbix/api_jsonrpc.php" );

eval {
    $zabbix->login(
        user     => $zbconf->{'user'},
        password => $zbconf->{'pass'}
    );
};
if ($@) { die 'could not authenticate' }

my $items = $zabbix->fetch(
    'Item',
    params => {
        groupids => 21,
        hostids  => 11036,
        graphids => 1824829,
    }
);
for my $item (@$items) {
    say $item->data->{'name'};
    my $itemid = $item->data->{'itemid'};
    say $itemid;
    my $sitems = $zabbix->fetch_single(
        'Item',
        params => {
            itemids => $itemid,
        }
    );
    my $pdl = pdl(map {$_->{value}} @{ $sitems->history( time_from => time() - 24 * 3600 ) });
    bin(hist($pdl));
    my $lline = pct($pdl, 0.25);
    my $uline = pct($pdl, 0.75);
    my $low = 2 * $lline - $uline;
    my $up  = 2 * $uline - $lline;
    say $pdl->where($pdl>$up | $pdl<$low);
}
{% endhighlight %}

这里使用了 [Zabbix2::API](https://metacpan.org/pod/Zabbix2::API) 模块，相对比 [zabbix 官方博客示例](http://blog.zabbix.com/getting-started-with-zabbix-api/1381/)直接使用 [JSON::RPC](https://metacpan.org/pod/JSON::RPC) 模块，以及 python 的 pyzabbix 模块来说，Zabbix2::API 模块封装的非常好，history 是作为 item 对象的属性出现，而不是单独再请求一次 `history.get`；item 的 name 等属性也非常友好和有用。

另外，不知道为什么，使用 pyzabbix 模块就一直无法正常使用，而自己写 requests 和 json 却没问题。上面的 perl 脚本用 python 改写就是下面这样：

{% highlight python %}
#!/usr/bin/env python
"""
Read item history from zabbix, and plot as histogram
"""
import matplotlib
import numpy as np
import matplotlib.mlab as mlab
import matplotlib.pyplot as plt
import requests
import json
import time
from datetime import datetime

ZABBIX_URI = 'http://test.zabbix.com/zabbix/api_jsonrpc.php'
ZABBIX_USR = 'user'
ZABBIX_PWD = 'pass'
HOURS = 24 * 1

def zabbixLogin(user, passwd):
  params = {
    'user':user,
    'password':passwd
  }
  return zabbixCall('user.login', params)

def zabbixCall(method='', params={}, auth=''):
  data = {
    'jsonrpc':'2.0',
    'method':method,
    'params':params,
    'id':1
  }
  if len(auth) != 0:
    data['auth'] = auth
  r = requests.post(ZABBIX_URI, data=json.dumps(data), headers={'content-type':'application/json-rpc'})
  return r.json()['result']

authId = zabbixLogin(ZABBIX_USR, ZABBIX_PWD)
params = {
  'groupids':21,
  'hostids':11036,
  'graphids':1824829
}
items = zabbixCall('item.get', params, authId)

begin = time.mktime(datetime.now().timetuple()) - 3600 * HOURS
for item in items:
  params = {
    'output':'extend',
    'history':0,
    'itemids':item['itemid'],
    'time_from':begin
  }
  ret = zabbixCall('history.get', params, authId)
  history = map(lambda x: float(x['value']), ret)
  v = np.array(history)

  plt.figure()
  plt.hist(v, bins=200, normed=1)
  plt.title('item: ' + item['itemid'])

#  lline = numpy.percentile(v, 25)
#  uline = numpy.percentile(v, 75)
#  low = 2 * lline - uline
#  up = 2 * uline - lline
  plt.figure()
  plt.boxplot(v, sym='+', notch=True)
  plt.title('item: ' + item['itemid'])
  plt.show()
{% endhighlight %}
