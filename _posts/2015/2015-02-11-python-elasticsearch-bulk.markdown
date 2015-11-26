---
layout: post
title: Python 批量写入 Elasticsearch 脚本
category: logstash
tags:
  - python
  - pypy
  - elasticsearch
---

Elasticsearch 官方和社区提供了各种各样的客户端库，在之前的博客中，我陆陆续续提到和演示过 Perl 的，Javascript 的，Ruby 的。上周写了一版 Python 的，考虑到好像很难找到现成的示例，如何用 python 批量写数据进 Elasticsearch，今天一并贴上来。

```python
#!/usr/bin/env pypy
#coding:utf-8

import re
import sys
import time
import datetime
import logging
from elasticsearch import Elasticsearch
from elasticsearch import helpers
from elasticsearch import ConnectionTimeout

es = Elasticsearch(['192.168.0.2', '192.168.0.3'], sniff_on_start=True, sniff_on_connection_fail=True, max_retries=3, retry_on_timeout=True)
logging.basicConfig()
logging.getLogger('elasticsearch').setLevel(logging.WARN)
logging.getLogger('urllib3').setLevel(logging.WARN)

def parse_www(logline):
	try:
		time_local, request, http_user_agent, staTus, remote_addr, http_referer, request_time, body_bytes_sent, http_x_forwarded_proto, http_x_forwarded_for, http_host, http_cookie, upstream_response_time = logline.split('`')
		try:
			upstream_response_time = float(upstream_response_time)
		except:
			upstream_response_time = None

		method, uri, verb = request.split(' ')
		arg = {}
		try:
			url_path, url_args = uri.split('?')
			for args in url_args.split('&'):
				k, v = args.split('=')
				arg[k] = v
		except:
			url_path = uri

		# Why %z do not implement?
	        date = datetime.datetime.strptime(time_local, '[%d/%b/%Y:%H:%M:%S +0800]')
		ret = {
			"@timestamp": date.strftime('%FT%T+0800'),
			"host": "127.0.0.1",
			"method": method.lstrip('"'),
			"url_path": url_path,
			"url_args": arg,
			"verb": verb.rstrip('"'),
			"http_user_agent": http_user_agent,
			"status": int(staTus),
			"remote_addr": remote_addr.strip('[]'),
			"http_referer": http_referer,
			"request_time": float(request_time),
			"body_bytes_sent": int(body_bytes_sent),
			"http_x_forwarded_proto": http_x_forwarded_proto,
			"http_x_forwarded_for": http_x_forwarded_for,
			"http_host": http_host,
			"http_cookie": http_cookie,
			"upstream_response_time": upstream_response_time
		}
		return {"_index":"logstash-mweibo-www-"+date.strftime('%Y.%m.%d'), "_type":"nginx","_source":ret}
	except:
		return {"_index":"logstash-mweibo-www-"+datetime.datetime.now().strftime('%Y.%m.%d'), "_type":"nginx","_source":{"message":logline}}

def get_log():
    start_time = time.time()
    log_buffer = []
    while True:
        try:
            line = sys.stdin.readline()
        except:
            break
        if not line:
            helpers.bulk(es, log_buffer)
            del log_buffer[0:len(log_buffer)]
            break

        if line:
            ret = parse_www(line.rstrip())
            log_buffer.append(ret)
            while ( len(log_buffer) > 2000 and len(log_buffer) % 2000 == 0 ):
                try:
                    helpers.bulk(es, log_buffer)
                except ConnectionTimeout:
                    print("try again")
                    continue
                del log_buffer[0:len(log_buffer)]
                break

        else:
            if (time.time() - startime > timeout ):
                helpers.bulk(es, log_buffer)
                start_time = time.time()
                del log_buffer[0:len(log_buffer)]
            time.sleep(1)

if __name__ == '__main__':
    get_log()
```

和 Perl、Ruby 的客户端不同，Python 的客户端只支持两种 transport 方式，urllib3 或者 thrift。也就是说，木有像事件驱动啊之类的办法。

测试一下，这个脚本如果不发送数据，一秒处理日志条数在15k，发送数据，一秒只有2k。确实比较让人失望，于是决定换成 pypy 试试——我司不少日志处理脚本都是用 pypy 运行的。

服务器上使用 pypy ，是通过 EPEL 安装的，之前都只用核心模块，这次需要安装 elasticsearch 模块。所以需要先给 pypy 加上 pip：

    wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
    pypy get-pip.py

网上大多说之前还要下载一个叫 distribute_setup.py 的脚本来运行，实测不需要，而且这个脚本的下载链接也失效了。

然后通过 pip 安装 elasticsearch 包即可：

    /usr/lib64/pypy-2.0.2/bin/pip install elasticsearch

测试，pypy 比 python 处理日志速度快一倍，写 ES 速度快一半。不过 3300eps 依然很慢就是了。

## 测试中碰到的其他问题

可以看到脚本里已经设置了多次重试和超时重连，不过依然会收到写入超时和失败的返回，原来 Elasticsearch 默认对每个 node 做 segment merge 的时候，有磁盘保护措施，速度上限限制在 20MB/s。这在压测的时候就容易触发。

> [2015-01-10 09:41:51,273][INFO ][index.engine.internal ] [node1][logstash-2015.01.10][2] now throttling indexing: numMergesInFlight=6,maxNumMerges=5

修改配置重启即可：

```yaml
indices.store.throttle.type：merge
indices.store.throttle.max_bytes_per_sec：500mb
```

关于这个问题，ES 也有讨论：[Should we lower the default merge IO throttle rate?](https://github.com/elasticsearch/elasticsearch/issues/6081)。或许未来会有更灵活的策略。

更多 ES 性能测试和优化建议，参考：<http://www.elasticsearch.org/guide/en/elasticsearch/guide/current/indexing-performance.html>
