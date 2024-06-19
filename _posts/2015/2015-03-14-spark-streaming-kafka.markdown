---
layout: post
theme:
  name: twitter
title: spark streaming 接收 kafka 数据示例
category: monitor
tags:
  - spark
  - kafka
  - scala
---

上个月曾经试过了用 spark streaming 读取 logstash 启动的 TCP Server 的数据。不过如果你有多台 logstash 的时候，这种方式就比较难办了 —— 即使你给 logstash 集群申请一个 VIP，也很难确定说转发完全符合。所以一般来说，更多的选择是采用 kafka 等队列方式由 spark streaming 去作为订阅者获取数据。

## 环境部署

这里只讲 kafka 单机的部署。只是示例嘛：

    cd kafka_2.10-0.8.2.0/bin/
    ./zookeeper-server-start.sh ../config/zookeeper.properties &
    ./kafka-server-start.sh --daemon ../config/server.properties

## 数据转发

保持跟之前示例的连贯性，这里继续用 logstash 发送数据到 kafka。

首先创建一个 kafka 的 topic：

    ./kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic logstash

然后到 logstash 里，修改配置为：

    input {
        file { path => "/var/log/*.log" }
    }
    filter {
        ruby {
            code => "event['lineno'] = 100 * rand(Math::E..Math::PI)"
        }
    }
    output {
        kafka {
            broker_list => "127.0.0.1:9092"
            topic_id => "logstash"
        }
    }

## spark streaming 处理的代码：

处理效果跟之前示例依然保持一致，就不重复贴冗余的函数了，只贴最开始的处理部分：

```java
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.StreamingContext._
import org.apache.spark.streaming.kafka.KafkaUtils
import org.json4s._
import org.json4s.jackson.JsonMethods._

object LogStash {

  implicit val formats = DefaultFormats
  case class LogStashV1(message:String, path:String, host:String, lineno:Double, `@timestamp`:String)

  def main(args: Array[String]) {

    val Array(zkQuorum, group, topics, numThreads) = args
    val topicMap = topics.split(",").map((_,numThreads.toInt)).toMap

    val sparkConf = new SparkConf().setMaster("local[2]").setAppName("LogStash")
    val sc  = new SparkContext(sparkConf)
    val ssc = new StreamingContext(sc, Seconds(10))

    val lines = KafkaUtils.createStream(ssc, zkQuorum, group, topicMap).map(_._2)

    lines.map(line => {
      val json = parse(line)
      json.extract[LogStashV1]
    }).print()

    ssc.start()
    ssc.awaitTermination()
  }
}
```

这里面有一些跟网上常见资料不一样的地方。

第一个，`import org.apache.spark.streaming.kafka._` 并不会导出 `KafkaUtils`，必须明确写明才行。
第二个，之前示例里用了 scala 核心自带的 JSON 模块。但是这次我把 lineno 字段从整数改成浮点数后，发现 `JSON.parseFull()` 有问题。虽然我在 scala 的 repl 里测试没问题，但是写在 spark 里的时候，它并不像文档所说的"总是尝试解析成 Double 类型"，而是一直尝试用 `Integer.parseInteger()` 方法来解析。哪怕我明确定义 `JSON.globalNumberParser = {input:String => Float.parseFloat(input)}` 都不起作用。

所以，最后这里改用了 [json4s 库](http://json4s.org)。据称这也是 scala 里性能和功能最好的 JSON 库。

json4s 库默认解析完后，不是标准的 Map、List 等对象，而是它自己的 JObject、JList、JString 等。想要转换成标准 scala 对象，需要调用 `.values` 才对。不过我这个示例里没有这么麻烦，而是直接采用 `.extract` 就变成了 cast class 对象了。非常简便。

另一个需要点出来的变动是：因为采用 `.extract`，所以 cast class 里的参数命名必须跟 JSON 里的 key 完全对应上。而我们都知道 logstash 里有几个特殊的字段，叫 `@timestamp` 和 `@version` 。这个 "@" 是不能直接裸字符的，所以要用反引号(**`**)包括起来。

## sbt 打包

sbt 打包也需要有所变动。spark streaming 的核心代码中，并不包含 kafka 的代码。还跟之前那样 `sbt package` 的话，就得另外指定 kafka 的 jar 地址才能运行了。更合适的办法，是打包一个完全包含的 jar 包。这就用到 [sbt-assembly 扩展](https://github.com/sbt/sbt-assembly)。

*刚刚收到的消息，spark 1.3 版发布 beta 了，spark streaming 会内置对 kafka 的底层直接支持。或许以后不用这么麻烦？*

sbt-assembly 使用起来特别简单，尤其是当你使用的 sbt 版本比较新(大于 0.13.6) 的时候。

1. 添加扩展

在项目的 `project/` 目录下创建一个 `plugins.sbt` 文件，内容如下：

    addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "0.13.0")

具体的版本选择，看官方 README 的 [Setup 部分](https://github.com/sbt/sbt-assembly#setup)。

2. 添加新增依赖模块

现在可以去修改我们项目的 `build.sbt` 了：

```scala
name := "LogStash"

version := "1.0"

scalaVersion := "2.10.4"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % "1.2.0" % "provided",
  "org.apache.spark" %% "spark-sql" % "1.2.0" % "provided",
  "org.apache.spark" %% "spark-streaming" % "1.2.0" % "provided",
  "org.apache.spark" %% "spark-streaming-kafka" % "1.2.0",
  "org.json4s" %% "json4s-native" % "3.2.10",
  "org.json4s" %% "json4s-jackson" % "3.2.10"
)
```

是的。新版本的 sbt-assembly 完全不需要单独修改 `build.sbt` 了。

需要注意，因为我们这次是需要把各种依赖全部打包到一起，这个可能会导致一些文件相互有冲突。比如我们用 spark-submit 提交任务，有关 spark 的核心文件，本身里面就已经有了的，那么就需要额外通过 `% "provided"` 指明这部分会另外提供，不需要打进去。这样运行的时候就不会有问题了。

3. 打包

采用 sbt-assembly 后的打包命令是：`sbt assembly`。注意输出的结果，会是直接读取 `build.sbt` 里的 `name` 变量，不做处理。，我们之前定义的叫 "LogStash Project"，`sbt package` 命令自动会转换成全小写且空格改成中横线的格式 *logstash-project_2.10-1.0.jar*。但是 `sbt assembly` 就会打包成 *LogStash Project-assembly-1.0.jar* 包。这个空格在走 spark-submit 提交的时候是有问题的。所以这里需要把 name 改成一个不会中断的字符串。。。
