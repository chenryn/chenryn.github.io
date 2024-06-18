---
layout: post
title: 日志异常检测能转换成指标异常检测吗？
category: aiops
tags:
  - logmine
  - drain
---

题目上这个问题，做日志异常检测的时候很容易被问到。而且我们也看到很多市面上的产品似乎都不满足于简单的根据聚类结果来发现异常格式的日志记录，想着：”难道就不能再把正常聚类的数据量统计转换成指标数据，然后做个指标异常检测吗？“

其实类似思路在 UEBA 安全场景中也有，所谓基于属性基线的异常行为检测，大致就是拿单个账号的时序指标和同一个聚类的时序指标做相似度对比。

但差别就在到底是直接指标异常检测，还是做双指标的相似度对比了。今天，我们拿一份实际数据，看看，日志聚类后的结果，真的适合指标异常检测么？

日志聚类方面，我们直接使用 IBM 开源的 Drain3 改进算法，<https://github.com/IBM/drain3>。相信大厂嘛~重要的是作为调研，直接 `pip install drain3` 安装方便。

以项目中 examples/http://drain_bigfile_demo.py 为基准，稍作修改(改改 in_file 位置，分割一下时间段然后字典计数就够了)，就可以按时间得到不同日志模式的数据量趋势。示例代码里可以看到比较有趣的一点，就是直接用": "作为分隔符来获取日志中的 message 部分。这个方案简单粗暴，但是对多数 syslog、log4j 场景还都挺有效的——按我们的经验，如果带上 log header 部分，最终效果其实反而不好。

```
for line in lines:
    line = line.rstrip()
    timespan = line[0:4]
    line = line.partition(": ")[2]
    result = template_miner.add_log_message(line)
    line_count += 1
    cid = result["cluster_id"]
    if timespan in cluster_trend:
        if cid in cluster_trend[timespan]:
            cluster_trend[timespan][cid] += 1
        else:
            cluster_trend[timespan].update({cid:1})
    else:
        cluster_trend.update({timespan:{cid:1}})
```

以某客户实际的单日数据运行后，最后画出来的趋势图如下：

![](https://pic1.zhimg.com/v2-fb10730122439f2520e4af4e23afbfa4_r.jpg)

好几十个模式，显然看花眼了。换回表格，就能发现问题：

![](https://pic3.zhimg.com/v2-f4a0a17116d84b29df3c49dfe73b4c46_r.jpg)

上面的 python 片段里可以发现，计数是以 10 分钟间隔进行的。换句话说，如果一个聚类模式的日志有稳定输出，一天应该有 144 个点。上面没一个聚类达标，甚至还差很远——你能想象对一个缺点高达 30%-90%的时间序列做异常检测么？？

不过完全放弃对正常模式的检测，可能确实有实际含义上的疑问。我们看看对应数据量最大的6个模式长这个样子(有脱敏修改，不影响结论)：

> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO <*> <*> - <*> <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.c.DispatcherController <*> - input <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO <*> <*> - <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO <*> <*> - <*> <*> <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.s.CallService [135] - retMsg 0=<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:NPServiceNamespace"> <soapenv:Header/> <soapenv:Body> <urn:Ack> <*> <urn:CommandCode>ACK</urn:CommandCode> <urn:ResponseCode>100</urn:ResponseCode> <urn:ErrorMessage></urn:ErrorMessage> </urn:Ack> </soapenv:Body></soapenv:Envelope>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.s.CallService <*> - <*> <*> <*> <*> <*> <*>

换神仙来也不知道这些模式有啥含义。

那是不是算法的原因呢？我们换一个开源实现，[logmine](https://github.com/trungdq88/logmine) 再对同一份数据试试。这个算法原理差别很大(训练速度是常见算法中最慢的 top3，所以大家如果复现我的过程时要耐心等几十秒)，但是同样安装方便，`pip install logmine` 就行了，而且会在/usr/local/bin/下自动放一个命令行，直接接收 stdin 运行。得到的对应数据量最大的6个模式是这样（为了和上面对比方便，我删掉了 header 部分）：

> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] <*> <*> <*> - <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.c.DispatcherController [97] - input soapPubCall requestBody[<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:NPServiceNamespace"> <soapenv:Header/> <soapenv:Body> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <urn:Remark/> <*> </soapenv:Body></soapenv:Envelope>]
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.s.CallService [135] - retMsg 0=<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.s.CallService <*> - <*> = <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*> <*>
> <*> for queue: 'weblogic.kernel.Default (self-tuning)'] INFO xxx.c.DispatcherController [199] - input <*> <*> <*> ServiceType=MOBILE, <*> <*> <*> <*> <*> <*> <*> Remark=null}]

可以看到两个不同算法聚类的结果相差甚远——但密密麻麻的通配符一样看不懂。

对看不懂的数据，确实需要一种保底的监控手段，防止问题出现未知区域——时序指标异常检测算法缺点太大没法使用，还有更简单的对比基线方法可用啊。基于同环比的波动比例阈值，在这个时候，就成为比较合适的选择了。

