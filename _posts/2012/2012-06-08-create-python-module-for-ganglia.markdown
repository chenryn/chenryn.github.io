---
layout: post
title: 用ganglia监控trafficserver
date: 2012-06-08
category: monitor
tags:
  - ganglia
  - python
  - ats
---

trafficserver提供了几种很不错的性能监控方式。首先是一个模仿cisco的shell工具./bin/traffic_shell——这个工具可以set变量，也可以show变量，另一个是类似squidclient的./bin/traffic_line工具——这个工具同样可以set和show变量，不过这里变量更接近源代码函数名的样子，相当于调用API了。此外还有Perl和Web的其他方式……

注：有些变量是可以动态修改的，有些比如内存大小之类的必须重启才生效。

用shell工具最方便，因为你单写个show，会提示你所有可以show的参数。一般性能方面就是http-stats/http-trans-stats/proxy-stats/cache-stats这几个。淘宝ssd分支在这里增加了一个SSD吞吐量和RAM缓存命中率的显示。不过一开始，你会发现RAM Cache HITs一直是0.00%！！询问作者后才知道，为了尽量提高性能，默认配置下RAM命中后不统计数据直接pass了……需要在records.config里配置CONFIG proxy.config.http.record_tcp_mem_hit = 1 才行——这配置records.config.default里还没有，呵呵～～

长期监控来说，用shell工具就不方便了，就要改用line工具，不过这里line读取的API，官方文档里是不全的，有一个简单的办法，就是进src/mgmt/cli/ShowCmd.cc里去把Cli_RecordGetInt里的字符串全grep出来，然后慢慢挑拣吧～～

下面是一个python的脚本，用来在ganglia里监控几个我个人认为比较重要的trafficserver性能参数的。
```python
import os
import re
import sys
import time

ts_line = '/usr/local/trafficserver-ssd/bin/traffic_line'

def metric_read(name):
    command = "%s -r %s" % (ts_line, name)
    result = os.popen(command).readlines()
    if re.search("ratio|percent",name):
        return float(result[0]) * 100
    else:
        return float(result[0])

descriptors = [
    {
        'description':'Cache Bytes used',
        'name': 'proxy.process.cache.bytes_used',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'Bytes',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Cache size',
        'name': 'proxy.process.cache.bytes_total',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'Bytes',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Transactions per second',
        'name': 'proxy.node.user_agent_xacts_per_second',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'requests/sec',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Document hit rate',
        'name': 'proxy.node.cache_hit_ratio_avg_10s',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'%',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Bandwidth savings',
        'name': 'proxy.node.bandwidth_hit_ratio_avg_10s',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'%',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Cache percent free',
        'name': 'proxy.node.cache.percent_free',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'%',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Total document bytes from client',
        'name': 'proxy.process.http.user_agent_response_document_total_size',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'Bytes',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'Total SSD Serve Bytes',
        'name': 'proxy.process.http.ssd_serve_total_size',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'Bytes',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'RAM Cache Hits',
        'name': 'proxy.node.cache_hit_mem_ratio',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'%',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'HTTP Transaction Fresh Speeds',
        'name': 'proxy.node.http.transaction_msec_avg_10s.hit_fresh',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'ms',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
    {
        'description':'HTTP Transaction Now Cached Speeds',
        'name': 'proxy.node.http.transaction_msec_avg_10s.miss_cold',
        'call_back': metric_read,
        'time_max':10,
        'value_type':'float',
        'units':'ms',
        'slope':'both',
        'format':'%f',
        'groups':'trafficserver'
    },
]

def metric_init(params):
    return descriptors

def metric_cleanup():
    pass

if __name__ == '__main__':
    metric_init(None)

    while 1:
        for d in descriptors:
            v = d['call_back'](d['name'])
            print '%s = %.2f' % (d['name'], v)
        time.sleep(2)
        print '-'*11

```
个人之前从来没写过python，这个脚本完全照葫芦画瓢，万幸确实可以运行……

不过不太明白的就是，如果把def metric_read定义在descriptors数组后面，运行会报错。很奇怪python为什么会这样？

