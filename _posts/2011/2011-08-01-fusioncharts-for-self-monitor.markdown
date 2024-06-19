---
layout: post
theme:
  name: twitter
title: cdn自主监控(五):生成charts图像
date: 2011-08-01
category: monitor
tags:
  - funsioncharts
---

上篇完成了xml的输出，这篇开始说charts图像的生成。我们采用fusioncharts的免费版，之前博客有提到另一个amcharts，不过amcharts的免费版会在图像左上角加上自己amcharts.com的广告标识……
从fusioncharts官网下载free版的压缩包，有20MB大，不过其中对我们这个小项目有用的只有MSLine.swf/MSBar2D.swf/fusioncharts.js等。
说明：
1、官网介绍上写了支持perl，不过下载包里只有php/asp/jsp/rails的class，没有perl的。所以还是得采用js的方式；
2、js下有setDataURL和setDataXML两个方法，不过官方强烈建议使用setDataURL方法，这种方法可接受的数据量比setDataXML大很多。
页面html很简单，加如下js代码即可：
```javascript</script>
<script type="text/javascript">
var myChart = new FusionCharts("/Charts/MSBar2D.swf", "myChartId", "600", "500");
myChart.setDataURL(escape("/xml?begin=***&end=***&type=area"));
myChart.render("chartdiv");
</script>```
要点在这个escape()，如果URL里带参数的话，必须用escape()转码，不然的话第一个&之后的所有参数都会丢失掉！
在调试中注意到，为了忽略缓存，setDataURL()会在url最后跟上一个随机1-4位数字参数&curr=1234然后再发起请求。
现在就可以访问页面看看了～嗯，可以看到图像中的中文字有问题。这是因为fusioncharts不认utf8的中文，必须输出gbk或者gb2312的xml数据才行。所以需要修改一些dancer的charset配置，把config.yml里的charset: UTF-8改成charset: GBK。然后重新请求，中文就正确显示了。
如下图：
<img src="/images/uploads/fusioncharts.jpg" alt="" title="MSBar2D" width="400" height="350" class="alignnone size-full wp-image-2548" />
<hr />
题外话：因为数据是自己insert的，结果写了个区号0751，在quhao.txt里不存在，导致输出category的时候总有问题……难怪总看人说程序本身很好写，各种错误处理才是麻烦事……
