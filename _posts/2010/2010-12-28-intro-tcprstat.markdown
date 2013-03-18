---
layout: post
title: TCP响应时间监测
date: 2010-12-28
category: monitor
tags:
  - gnuplot
---

对于squid等服务器，其日志中就含有响应时间。但是，这个时间只是服务器软件处理过程的时间，进程一旦交出去，在网卡等处的时间，它就管不着了。而percona出品一款迷你型小工具，叫做tcprstat，正好派上用场~

tcprstat下载地址见：<http://www.percona.com/docs/wiki/tcprstat:start>

本来是percona用来监测mysql响应时间的。不过对于任何运行在TCP协议上的响应时间，都可以用。不过据我试验，（至少非编译的64位二进制版如此）这个工具对linux内核版本也是有要求的，我在RH的AS4上运行就提示kernel不够……

对于使用一个2000行代码的工具，网页上的说明已经相当清晰。直接开用吧：

{% highlight bash %}
wget http://github.com/downloads/Lowercases/tcprstat/tcprstat-static.v0.3.1.x86_64 --no-check-certificate -O /sbin/tcprstat
chmod +x /sbin/tcprstat
tcprstat -p 1521 -t 10 -n 0 -f '%T\t%n\t%M\t%a\t%95M\t%99M\n'
timestamp	count	max	avg	95_max	99_max
1293528181	339	4429229	142446	617688	2196833
{% endhighlight %}

That's all!

监听oracle的1521端口，每10秒一次统计，长期运行，输出格式为“UNIX时间，响应个数，最长响应时间，平均响应时间，95%响应时间，99%响应时间”（这个%可以自定义数值）

__注意：这个响应时间是microsecond，即us，等于0.000001s。__

突然想起来基调的smoke图。用这个输出数据给gnuplot，相当容易画出类似的效果~给不同%的数据定义渐进颜色画柱状图（注意叠加次序），avg画连线图，count或许可以画在top的x轴上~先贴个简易版的：

{% highlight tcl %}
set terminal png size 550,350 \
xffffff x000000 x404040 \
xcfcfcf x8a8a8a x4a4a4a x00ff00
set output "log.png"
set autoscale
set xdata time
set timefmt "%s"
set xlabel "time"
set ylabel "microsecond"
set title "Oracle response time"
set grid
plot "tcp.log" using 1:3 title 'max' with filledcurves x1, \
"tcp.log" using 1:6 title '97%' with filledcurves x1, \
"tcp.log" using 1:5 title '90%' with filledcurves x1, \
"tcp.log" using 1:4 title 'avg' with lines
{% endhighlight %}

效果如下：

![tcprstat-gnuplot](/images/uploads/log-2.png)
