---
layout: post
theme:
  name: twitter
title: spark streaming 和 spark sql 结合示例
category: monitor
tags:
  - logstash
  - spark
---

之前在博客上演示过如果在 spark 里读取 elasticsearch 中的数据。自然往下一步想，是不是可以把一些原先需要定期请求 elasticsearch 的监控内容挪到 spark 里完成？这次就是探讨一下 spark streaming 环境上如何快速统计各维度的数据。期望目标是，可以实现对流数据的异常模式过滤。平常只需要简单调整模式即可。

## spark 基础预备

之前作为示例，都是直接在 spark-shell 交互式命令行里完成的。这次说说在正式的情况下怎么做。

spark 是用 scala 写的，scala 的打包工具叫 sbt。首先通过 `sudo port install sbt` 安装好。然后创建目录：

    mkdir -p ./logstash/src/main/scala/

sbt 打包的配置文件则放在 `./logstash/logstash.sbt` 位置。内容如下(注意之间的空行是必须的)：

```java
name := "LogStash Project"

version := "1.0"

scalaVersion := "2.10.4"

libraryDependencies += "org.apache.spark" %% "spark-core" % "1.2.0"

libraryDependencies += "org.apache.spark" %% "spark-streaming" % "1.2.0"

libraryDependencies += "org.apache.spark" %% "spark-sql" % "1.2.0"
```

然后是程序主文件 `./logstash/src/main/scala/LogStash.scala`，先来一个最简单的，从 logstash/output/tcp 收数据并解析出来。注意，因为 spark 只能用 pull 方式获取数据，所以 logstash/output/tcp 必须以 `mode => 'server'` 方式运行。 

    output {
        tcp {
            codec => json_lines
            mode  => 'server'
            port  => 8888
        }
    }

## spark streaming 基础示例

编辑主文件如下：

```java
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.StreamingContext._
import scala.util.parsing.json.JSON

object LogStash {

  def main(args: Array[String]) {

    val sparkConf = new SparkConf().setMaster("local[2]").setAppName("LogStash")
    val sc  = new SparkContext(sparkConf)
    val ssc = new StreamingContext(sc, Seconds(10))

    val lines = ssc.socketTextStream("localhost", 8888)
    val jsonf = lines.map(JSON.parseFull(_)).map(_.get.asInstanceOf[scala.collection.immutable.Map[String, Any]])

    jsonf.filter(l => l("lineno")==75).window(Seconds(30)).foreachRDD( rdd => {
      rdd.foreach( r => {
        println(r("path"))
      })
    })

    ssc.start()
    ssc.awaitTermination()
  }

}
```

非常一目了然，每 10 秒挪动一次 window，window 宽度是 30 秒，把 JSON 数据解析出来以后，做过滤和循环输出。这里需要提示一下的是 `.foreachRDD` 方法。这是一个 output 方法。spark streaming 里对 input 收到的 DStream 一定要有 output 处理，那么最常见的就是用 foreachRDD 把 DStream 里的 RDDs 循环一遍，做 save 啊，print 啊等等后续。

然后用 sbt 工具编译后就可以运行了：

    sbt package && ./spark-1.2.0-bin-hadoop2.4/bin/spark-submit --class "LogStash" --master local[2] target/scala-2.10/logstash-project_2.10-1.0.jar

## 进阶：数据映射和 SQL 处理

下面看如何在 spark streaming 上使用 spark SQL。前面通过解析 JSON，得到的是 Map 类型的数据，这个无法直接被 SQL 使用。通常的做法是，通过预定的 scala 里的 `cast class`，来转换成 spark SQL 支持的表类型。主文件改成这样：

```java
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.StreamingContext._
import org.apache.spark.sql.SQLContext
import org.apache.spark.sql._
import scala.util.parsing.json.JSON

object LogStash {

  case class LogStashV1(message:String, path:String, host:String, lineno:Double, timestamp:String)
  case class AlertMsg(host:String, count:Int, value:Double)

  def main(args: Array[String]) {

    val sparkConf = new SparkConf().setMaster("local[2]").setAppName("LogStash")
    val sc  = new SparkContext(sparkConf)
    val ssc = new StreamingContext(sc, Seconds(10))

    val sqc = new SQLContext(sc)
    import sqc._

    val lines = ssc.socketTextStream("localhost", 8888)
    val jsonf = lines.map(JSON.parseFull(_)).map(_.get.asInstanceOf[scala.collection.immutable.Map[String, Any]])

    val logs = jsonf.map(data => LogStashV1(data("message").toString, data("path").toString, data("host").toString, data("lineno").toString.toDouble, data("@timestamp").toString))

    logs.foreachRDD( rdd => {
      rdd.registerAsTable("logstash")
      val sqlreport = sqc.sql("SELECT message, COUNT(message) AS host_c, SUM(lineno) AS line_a FROM logstash WHERE path = '/var/log/system.log' AND lineno > 70 GROUP BY message ORDER BY host_c DESC LIMIT 100")
      sqlreport.map(t => AlertMsg(t(0).toString, t(1).toString.toInt, t(2).toString.toDouble)).collect().foreach(println)
    })

    ssc.start()
    ssc.awaitTermination()
  }

}
```

通过加载 SQLContext，就可以把 RDD 转换成 table，然后通过 SQL 方式写请求了。这里有一个地方需要注意的是，因为最开始转换 JSON 的时候，键值对的 value 类型是 Any(因为要兼容复杂结构)，所以后面赋值的时候需要具体转换成合适的类型。于是悲催的就有了 `.toString.toInt` 这样的写法。。。

## 同样效果的非 SQL 实现

不用 spark SQL 当然也能做到，而且如果需要复杂处理的时候，还少不了自己写。如果把上例中那段 foreachRDD 替换成下面这样，效果是完全一样的：

```java
    val r = logs.filter(l => l.path.equals("/var/log/system.log")).filter(l => l.lineno > 70)
    val host_c = r.map(l => l.message -> 1).reduceByKey(_+_).groupByKey()
    r.map(l => l.message -> l.lineno).reduceByKey(_+_).groupByKey().join(host_c).foreachRDD( rdd => {
        rdd.map(t => AlertMsg(t._1, t._2._2.head, t._2._1.head)).collect().foreach(println)
    })
```

这里面用到的 `.groupByKey` 和 `.reduceByKey` 方法，都是专门针对 PairsDStream 对象的，所以前面必须通过 `.map` 方法把普通 DStream 转换一下。

这里还有一个很厉害的方法，叫 `.updatestateByKey` 。可以有一个 checkpoint 存上一个 window 的数据，具体示例稍后更新。

## 更简洁的 jsonRDD 方法

在简单需求的时候，可能还是觉得能用 SQL 就用 SQL 比较好。但是提前定义 cast class 真的比较麻烦。其实对于 JSON 数据，spark SQL 是有提供更简洁的处理接口的。可以直接写成这样：

```java
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.StreamingContext._
import org.apache.spark.sql.SQLContext
import org.apache.spark.sql._

object LogStash {

  case class AlertMsg(host:String, count:String, value:String)

  def main(args: Array[String]) {

    val sparkConf = new SparkConf().setMaster("local[2]").setAppName("LogStash")
    val sc  = new SparkContext(sparkConf)
    val ssc = new StreamingContext(sc, Seconds(10))
    val sqc = new SQLContext(sc)
    import sqc._

    val lines = ssc.socketTextStream("localhost", 8888)

    lines.foreachRDD( rdd => {
      if (rdd.count > 0) {
        val t = sqc.jsonRDD(rdd)
//        t.printSchema()
        t.registerTempTable("logstash")
        val sqlreport =sqc.sql("SELECT host, COUNT(host) AS host_c, AVG(lineno) AS line_a FROM logstash WHERE path = '/var/log/system.log' AND lineno > 70 GROUP BY host ORDER BY host_c DESC LIMIT 100")
        sqlreport.map(t=> AlertMsg(t(0).toString,t(1).toString,t(2).toString)).collect().foreach(println)
      }
    })

    ssc.start()
    ssc.awaitTermination()
  }
}
```

这样，不用自己解析 JSON，直接加载到 SQLContext 里。可以通过 `.printSchema` 方法查看到 JSON 被转换成了什么样的表结构。

## TODO

SQL 的方式可以很方便的做到对实时数据的阈值监控处理，但是 SQL 是建立在 RDD 上的如何利用 DStream 的上一个 window 的 state 状态实现比如环比变化处理，移动均线处理，还没找到途径。

## See Also

spark 目前文档不多，尤其是 streaming 和 SQL 方面的。感谢下面两个网址，对我上手帮助颇多：

* <http://apache-spark-user-list.1001560.n3.nabble.com/Spark-Streaming-Json-file-groupby-function-td9618.html>
* <http://databricks.gitbooks.io/databricks-spark-reference-applications/content/logs_analyzer/chapter1/windows.html>
