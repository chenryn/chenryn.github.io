---
layout: post
theme:
  name: twitter
title: spark streaming 的 transform 操作示例
category: monitor
tags:
  - spark
  - scala
---

前两篇，一篇说在 spark 里用 SQL 方便，一篇说 updatestateByKey 可以保留状态做推算。那么怎么综合起来呢？目前看到的 spark streaming 和 spark SQL 的示例全都是在 output 阶段的 `foreachRDD` 里才调用 SQL。实际在 output 之前，也是可以对 DStream 里的 RDD 做复杂的转换操作的，这就是 `transform` 方法。

通过 `transform` 方法，可以做到 SQL 请求的结果依然是 DStream 数据，这样就可以使用 `updateStateByKey` 方法了。下面是示例：

```java
import org.apache.spark.SparkConf
import org.apache.spark.sql._
import org.apache.spark.sql.SQLContext
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.StreamingContext._

object LogStash {

  case class Status(avg:Double = 0.0, count:Int = 0) {
    var countTrend = 0.0
    var avgTrend = 0.0
    def %(prev:Status): Status = {
      if (prev.count > 0) {
        this.countTrend = (this.count - prev.count).toDouble / prev.count
      }
      if (prev.avg > 0) {
        this.avgTrend = (this.avg - prev.avg) / prev.avg
      }
      this
    }
    override def toString = {
      s"Trend($avg, $count, $avgTrend, $countTrend)"
    }
  }

  def updatestatefunc(newValue: Seq[Status], oldValue: Option[Status]): Option[Status] = {
    val prev = oldValue.getOrElse(Status())
    val current = if (newValue.size > 0) newValue.last % prev else Status()
    Some(current)
  }

  def main(args: Array[String]) {

    val sparkConf = new SparkConf().setMaster("local[2]").setAppName("LogStash")
    val sc  = new SparkContext(sparkConf)

    val ssc = new StreamingContext(sc, Seconds(10))
    ssc.checkpoint("/tmp/spark-streaming-logstash")

    val sqc = new SQLContext(sc)
    import sqc._

    val lines = ssc.socketTextStream("localhost", 8888)

    lines.transform( rdd => {
      if (rdd.count > 0) {
        sqc.jsonRDD(rdd).registerTempTable("logstash")
        val sqlreport = sqc.sql("SELECT message, COUNT(message) AS host_c, AVG(lineno) AS line_a FROM logstash WHERE path = '/var/log/system.log' AND lineno > 70 GROUP BY message ORDER BY host_c DESC LIMIT 100")
        sqlreport.map(r => (r(0).toString -> Status(r(2).toString.toDouble, r(1).toString.toInt)))
      } else {
        rdd.map(l => ("" -> Status()))
      }
    }).updateStateByKey(updatestatefunc).print()

    ssc.start()
    ssc.awaitTermination()
  }
}
```

这里有一点需要注意，也是耽误我时间最多的地方：`transform` 方法的参数和返回，代码里的定义是 `RDD[T]` 和 `RDD[U]`。我不懂 Java/Scala，以为是只要是 RDD 对象即可。实践证明，其实要任意场合下返回的 RDD 里的数据类型也保持一致。

在上例中，就是 if 条件下返回的是 `RDD[(String, Status)]`，那么 else 条件下，也必须返回一个 `RDD[(String, Status)]`，如果直接返回原始的 rdd(也就是 `RDD[String]`)，就会报错。

