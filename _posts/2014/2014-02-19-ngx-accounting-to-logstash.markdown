---
layout: post
title: 用 logstash 统计 Nginx 的 http_accounting 模块输出
category: logstash
tags:
  - nginx
  - logstash
  - syslog
---

继续捡宝贝~

http_accounting 是 Nginx 的一个第三方模块，会每隔5分钟自动统计 Nginx 所服务的流量，然后发送给 syslog。

流量以 `accounting_id` 为标签来统计，这个标签可以设置在 `server {}` 级别，也可以设置在 `location /urlpath {}` 级别，非常灵活。
统计的内容包括响应字节数，各种状态码的响应个数。

公司原先是有一套基于 rrd 的[系统](https://github.com/Lax/ngx_http_accounting_module-utils)，来收集处理这些 syslog 数据并作出预警判断、异常报警。不过今天不讨论这个，而是试图用最简单的方式，快速的搞定类似的中心平台。

这里当然是 logstash 的最佳用武之地。

`logstash.conf` 示例如下：

```
input {
    syslog {
        port => 29124
    }
}
filter {
    grok {
        match => [ "message", "^%{SYSLOGTIMESTAMP:timestamp}\|\| pid:\d+\|from:\d{10}\|to:\d{10}\|accounting_id:%{WORD:accounting}\|requests:%{NUMBER:req:int}\|bytes_out:%{NUMBER:size:int}\|(?:200:%{NUMBER:count.200:int}\|?)?(?:206:%{NUMBER:count.206:int}\|?)?(?:301:%{NUMBER:count.301:int}\|?)?(?:302:%{NUMBER:count.302:int}\|?)?(?:304:%{NUMBER:count.304:int}\|?)?(?:400:%{NUMBER:count.400:int}\|?)?(?:401:%{NUMBER:count.401:int}\|?)?(?:403:%{NUMBER:count.403:int}\|?)?(?:404:%{NUMBER:count.404:int}\|?)?(?:499:%{NUMBER:count.499:int}\|?)?(?:500:%{NUMBER:count.500:int}\|?)?(?:502:%{NUMBER:count.502:int}\|?)?(?:503:%{NUMBER:count.503:int}\|?)?"
    }
    date {
        match => [ "timestamp", "MMM dd YYY HH:mm:ss", "MMM  d YYY HH:mm:ss", "ISO8601" ]
    }
}
output {
    elasticsearch {
        embedded => true
    }
}
```

然后运行 `java -jar logstash-1.3.3-flatjar.jar agent -f logstash.conf` 即可完成收集入库！
再运行 `java -jar logstash-1.3.3-flatjar.jar web` 即可在9292端口访问到 Kibana 界面。

上面这个 grok 写的很难看，不过似乎也没有更好的办法～下一步会研究在这个基础上合并 skyline 预警。
