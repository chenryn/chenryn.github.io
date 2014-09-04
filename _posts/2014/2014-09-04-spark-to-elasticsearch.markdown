---
layout: post
title: 用 Spark 处理数据导入 Elasticsearch
category: logstash
tags:
  - elasticsearch
  - spark
  - scala
---

Logstash 说了这么多。其实运用 Kibana 和 Elasticsearch 不一定需要 logstash，其他各种工具导入的数据都可以。今天就演示一个特别的~用 Spark 来处理导入数据。

首先分别下载 spark 和 elasticsearch-hadoop 的软件包。注意 elasticsearch-hadoop 从最新的 2.1 版开始才带有 spark 支持，所以要下新版：

{% highlight bash %}
wget http://d3kbcqa49mib13.cloudfront.net/spark-1.0.2-bin-cdh4.tgz
wget http://download.elasticsearch.org/hadoop/elasticsearch-hadoop-2.1.0.Beta1.zip
{% endhighlight %}

分别解压开后，运行 spark 交互命令行 `ADD_JARS=../elasticsearch-hadoop-2.1.0.Beta1/dist/elasticsearch-spark_2.10-2.1.0.Beta1.jar ./bin/spark-shell` 就可以逐行输入 scala 语句测试了。

**注意 elasticsearch 不支持 1.6 版本的 java，所以在 MacBook 上还设置了一下 `JAVA_HOME="/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home"` 启用自己从 Oracle 下载安装的 1.7 版本的 Java。**

基础示例
============

首先来个最简单的测试，可以展示写入 ES 的用法：

{% highlight java %}
import org.apache.spark.SparkConf
import org.elasticsearch.spark._

# 更多 ES 设置，见<http://www.elasticsearch.org/guide/en/elasticsearch/hadoop/2.1.Beta/configuration.html>
val conf = new SparkConf()
conf.set("es.index.auto.create", "true")
conf.set("es.nodes", "127.0.0.1")

# 在spark-shell下默认已建立
#import org.apache.spark.SparkContext    
#import org.apache.spark.SparkContext._
#val sc = new SparkContext(conf)

val numbers = Map("one" -> 1, "two" -> 2, "three" -> 3)
val airports = Map("OTP" -> "Otopeni", "SFO" -> "San Fran")

sc.makeRDD(Seq(numbers, airports)).saveToEs("spark/docs")
{% endhighlight %}

这就 OK 了。尝试访问一下：

    $ curl '127.0.0.1:9200/spark/docs/_search?q=*'

返回结果如下：

{% highlight json %}
{"took":66,"timed_out":false,"_shards":{"total":5,"successful":5,"failed":0},"hits":{"total":2,"max_score":1.0,"hits":[{"_index":"spark","_type":"docs","_id":"BwNJi8l2TmSRTp42GhDmww","_score":1.0, "_source" : {"one":1,"two":2,"three":3}},{"_index":"spark","_type":"docs","_id":"7f7ar-9kSb6WEiLS8ROUCg","_score":1.0, "_source" : {"OTP":"Otopeni","SFO":"San Fran"}}]}}
{% endhighlight %}

文件处理
===========

下一步，我们看如何读取文件和截取字段。scala 也提供了正则和捕获的方法：

{% highlight java %}
var text = sc.textFile("/var/log/system.log")
var Pattern = """(\w{3}\s+\d{1,2} \d{2}:\d{2}:\d{2}) (\S+) (\S+)\[(\d+)\]: (.+)""".r
var entries = text.map {
    case Pattern(timestamp, host, program, pid, message) => Map("timestamp" -> timestamp, "host" -> host, "program" -> program, "pid" -> pid, "message" -> message)
    case (line) => Map("message" -> line)
}
entries.saveToEs("spark/docs")
{% endhighlight %}

这里示例写了两个 `case` ，因为 Mac 上的 "system.log" 不知道用的什么 syslog 协议，有些在 `[pid]` 后面居然还有一个 `(***)` 才是 `:`。正好就可以用这个来示例如果匹配失败的情况如何处理。不加这个默认 `case` 的话，匹配失败的就直接报错不会存进 `entries` 对象了。

**注意：`.textFile` 不是 scala 标准的读取文件函数，而是 sparkContext 对象的方法，返回的是 RDD 对象(包括后面的 `.map` 返回的也是新的 RDD 对象)。所以后面就不用再 `.makeRDD` 了。**

网络数据
============

Spark 还有 Spark streaming 子项目，用于从其他网络协议读取数据，比如 flume，kafka，zeromq 等。官网上有一个配合 `nc -l` 命令的示例程序。

有时间我会继续尝试 Spark 其他功能。


