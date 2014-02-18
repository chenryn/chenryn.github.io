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
    syslog {}
}
filter {
    grok {
        match => [ "message", "^%{SYSLOGTIMESTAMP:timestamp}\|\| pid:\d+\|from:\d{10}\|to:\d{10}\|accounting_id:(?<accounting>\w+)\|requests:(?<req>\d+)\|bytes_out:(?<size>\d+)\|(?:200:(?<count_200>\d+)\|?)?(?:206:(?<count_206>\d+)\|?)?(?:301:(?<count_301>\d+)\|?)?(?:302:(?<count_302>\d+)\|?)?(?:304:(?<count_304>\d+)\|?)?(?:400:(?<count_400>\d+)\|?)?(?:401:(?<count_401>\d+)\|?)?(?:403:(?<count_403>\d+)\|?)?(?:404:(?<count_404>\d+)\|?)?(?:499:(?<count_499>\d+)\|?)?(?:500:(?<count_500>\d+)\|?)?(?:502:(?<count_502>\d+)\|?)?(?:503:(?<count_503>\d+)\|?)?" ]
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
