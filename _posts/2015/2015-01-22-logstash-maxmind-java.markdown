---
layout: post
title: JRuby 调用 maxmind-java 测试
category: logstash
tags:
  - geoip
  - ruby
  - performance
  - java
---

GeoIP 是一个非常有用的信息，也是使用 ELKstack 时一般都会加上的过滤器插件。不过 geoip 插件的性能，有些时候却会成为整个系统的瓶颈。另一个问题，则是 GeoIP 数据文件的准确度，在国内比较头疼。即使你有一个自己处理出来的准确度较高的 IP 库，GeoIP 也没有提供现成的修改数据文件内容的工具。这个时候，MaxMind 公司的 GeoIP2 就进入我的视线了。

GeoIP2 在字段上比 GeoIP 更丰富。而且还提供了 [MaxMind::DB::Writer](https://metacpan.org/pod/MaxMind::DB::Writer) 库方便使用者自己生成 GeoIP2 数据文件！感谢[@纯白色燃烧](http://weibo.com/345198426)童鞋用[自己的 CPAN 库成功倒逼](http://blog.yikuyiku.com/?p=4144) MaxMind 公司。

据@纯白色燃烧 介绍，GeoIP2 比 GeoIP 有六到七倍的性能提升。不过他是在 C 平台下，使用 libmaxminddb 库做的测试，而 logstash 是 JRuby 平台，所以我们需要的是验证如何在 JRuby 上使用 GeoIP2，以及跟 GeoIP 的性能对比。

在 JRuby 上用模块，有两种方式，一种是纯 Ruby 实现，一种是纯 Java 实现。MaxMind 提供了纯 Java 实现，社区另外有一个纯 Ruby 实现的库。下面开始测试。

## 准备工作

首先需要准备环境。安装 JRuby，纯 Ruby 实现的 maxminddb 库；然后下载 GeoIP2 数据文件，下载 Java 实现的 MaxMind-Java 库。

    sudo port install jruby
    sudo jgem install maxminddb
    wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz
    gzip -d GeoLite2-City.mmdb.gz
    wget https://github.com/maxmind/GeoIP2-java/releases/download/v2.1.0/geoip2-2.1.0-with-dependencies.zip
    unzip geoip2-2.1.0-with-dependencies.zip

## 测试程序

准备就绪，然后就是如何测试的问题了。为了贴近 logstash 运行环境，我扒拉了一下 logstash 最核心的 `pipeline.rb` 文件，简化出来了一个测试程序。相当于是 `logstash -w 20 -e 'input {generator {}} filter {geoip{}} output {null{}}` 的效果：

```ruby
#!/usr/bin/env jruby
require "geoip"
require "maxminddb"
require "thread"
require "java"

# 测试数据
ip = '202.106.0.20'

# 加载 maxmind-java 的所有 jar 包
Dir["/Users/raochenlin/geoip2-2.1.0/lib/*.jar"].each { |jar| require jar }

# 导入关键性的 java 类
import com.maxmind.geoip2.DatabaseReader
import java.net.InetAddress
# 这个原生的 java 写法是：
#   File database = new File("/Users/raochenlin/GeoLite2-City.mmdb")
#   DatabaseReader reader = new DatabaseReader.Builder(database).build()
# 之前对 java 不太懂，想直接 import Builder 进来
# 其实 Builder 是DatabaseReader 类里的静态类(public final static class)，不能直接 import
database = java.io.File.new("/Users/raochenlin/GeoLite2-City.mmdb")
@reader = DatabaseReader::Builder.new(database).build()

# 纯 Ruby 实现的库
@db = MaxMindDB.new('/Users/raochenlin/GeoLite2-City.mmdb')

# 老的 GeoIP 库，需要制定不同的数据文件类型，这部分直接抄自 logstash 源码
@geo = GeoIP.new('/Users/raochenlin/Downloads/logstash-1.4.2/vendor/geoip/GeoLiteCity.dat')
@geoip_type = case @geo.database_type
when GeoIP::GEOIP_CITY_EDITION_REV0, GeoIP::GEOIP_CITY_EDITION_REV1
  :city
when GeoIP::GEOIP_COUNTRY_EDITION
  :country
when GeoIP::GEOIP_ASNUM_EDITION
  :asn
when GeoIP::GEOIP_ISP_EDITION, GeoIP::GEOIP_ORG_EDITION
  :isp
else
  raise RuntimeException.new "This GeoIP database is not currently supported"
end

# 开始 logstash 流程
# 创建从 input 到 filter 的缓冲队列，固定大小 20
# SizedQueue 是 thread 库导入的
@input_to_filter = SizedQueue.new(20)

# 具体的 geoip 过滤器线程
def geoworker
    begin
        while true
            ip = @input_to_filter.pop

# GeoIP 查询方法
#            data = @geo.send(@geoip_type, ip)
#            puts data.to_hash[:city_name]

# MaxMind-java 查询方法，注意传入的是 InetAddress 对象
            data = @reader.city(InetAddress.getByName(ip))
#            puts data.getCountry().getName()

# maxminddb 查询方法
#            data = @db.lookup(ip)
#            puts data.country.name
        end
    end
end

# 定义 input 线程，传入一百万次 IP 到缓冲队列
lines_num = 1000000
input = Thread.new do
    lines_num.times.each do |i|
        @input_to_filter.push(ip)
    end
# IP 发送完毕，计算每秒处理的速率
    end_time = Time.now.to_f * 1000
    puts lines_num * 1000 / (end_time - @start_time)
end

# 定义 filter 线程，启动 20 个
arr = 20.times.collect do
    Thread.new do
        geoworker
    end
end

# 记录开始时间，运行定义好的各线程
@start_time = Time.now.to_f * 1000
input.join
arr.each{|t| t.join}
```

## 测试结果

在一百万次查询的测试中，结果如下：

1. geoip worker 的查询 qps 是：6038.902610617599
2. maxminddb worker 的查询 qps 是：4621.093443130513
3. maxmind-java worker 的查询 qps 是：27943.88867154753

可见，对于这部分有性能要求的，完全可以改用 `maxmind-java` 库，可以数倍提高。
