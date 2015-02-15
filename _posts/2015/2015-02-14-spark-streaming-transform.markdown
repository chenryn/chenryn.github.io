---
layout: post
title: spark streaming 的 transform 操作示例
category: monitor
tags:
  - spark
  - scala
---

前两篇，一篇说在 spark 里用 SQL 方便，一篇说 updatestateByKey 可以保留状态做推算。那么怎么综合起来呢？目前看到的 spark streaming 和 spark SQL 的示例全都是在 output 阶段的 `foreachRDD` 里才调用 SQL。实际在 output 之前，也是可以对 DStream 里的 RDD 做复杂的转换操作的，这就是 `transform` 方法。

通过 `transform` 方法，可以做到 SQL 请求的结果依然是 DStream 数据，这样就可以使用 `updateStateByKey` 方法了。下面是示例：

{% highlight java %}
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
    def +(avg:Double, count:Int): Status = {
      val newStatus = Status(avg, count)
      if (this.count > 0) {
        newStatus.countTrend = (count - this.count).toDouble / this.count
      }
      if (this.avg > 0) {
        newStatus.avgTrend = (avg - this.avg) / this.avg
      }
      newStatus
    }
    override def toString = {
      s"Trend($avg, $count, $avgTrend, $countTrend)"
    }
  }

  def updatestatefunc(newValue: Seq[(Double, Int)], oldValue: Option[Status]): Option[Status] = {
    val prev = oldValue.getOrElse(Status())
    var current = prev + ( newValue.map(_._1).sum, newValue.map(_._2).sum )
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
        sqlreport.map(r => s"${r(0)} ${r(1)} ${r(2)}")
      } else {
        rdd
      }
    }).map(l => {
      val a = l.split(" ")
      a(0) -> (a(2).toDouble, a(1).toInt)
    }).updateStateByKey(updatestatefunc).print()

    ssc.start()
    ssc.awaitTermination()
  }
}
{% endhighlight %}

这里有一点需要注意，也是耽误我时间最多的地方：`transform` 方法的参数和返回，代码里的定义是 `RDD[T]` 和 `RDD[U]`。我不懂 Java/Scala，以为是只要是 RDD 对象即可。实践证明，其实要 RDD 里的数据类型也保持一致。

放在上面示例里，就是 lines 里的数据是 `RDD[String]`，那么 transform 返回的数据也得是 `RDD[String]`，直接返回 `RDD[sql.Row]` 就不行。
