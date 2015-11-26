---
layout: post
title: gnuplot画图
date: 2010-08-13
category: monitor
tags:
  - gnuplot
---

之前提高日志流量统计的问题。并给出了分时流量的计算方法。当是想的是用perl调用rrd或者gd画图，甚至有把日志统计也写成perl的打算。
不过今天发现了一个小工具gnuplot，画图功能相当强大（在找资料的时候看到台湾有人用这个画台湾的三维地形图！），上手相当简单，尤其适合日志统计分析，相比来说，rrd还是比较适合实时监控画图的情况。
比如当初的脚本输出如下：
[root@Zabbix cache]# tail test.log
23:14 506.877
23:19 501.068
23:24 493.254
23:29 469.184
23:34 460.161
23:39 426.065
23:44 429.734
23:49 409.255
23:54 423.512
23:59 390.676
然后编写gnuplot的配置文件如下：
```bash
[root@Zabbix cache]# cat log.conf
set terminal png truecolor size 550,250    #指定输出成png图片，且图片大小为550×250，需要ligpng支持，采用默认颜色设定
set output "log.png"    #指定输出png图片的文件名
set autoscale    #轴向标记自动控制
set xdata time    #X轴数据格式为时间
set timefmt "%H:%M"    #时间输入格式为"小时:分钟"
set style data lines    #数据显示方式为连线
set xlabel "time per day"    #X轴标题
set ylabel "Mbps"    #Y轴标题
set title "image.tuku.china.com flow"    #图片标题
set grid    #显示网格
plot "test.log" using 1:2 title "access_flow"    #从test.log文件中读取第一列和第二列作为X轴和Y轴数据，示例名"log_flow"
```
最后运行cat log.conf | gnuplot命令，就生成了log.png文件，如下：
<img src="/images/uploads/gnuplot.png" alt="" />
就是不知道X轴上这个01/01怎么消除掉……
对比帝联提供的flash图片如下：
<img src="/images/uploads/dilian.jpg" alt="" />
可以看出基本是一致的。

