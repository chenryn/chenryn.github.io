---
layout: post
theme:
  name: twitter
title: weathermap-cacti-plugin学习(2)
date: 2010-11-26
category: monitor
tags:
  - cacti
  - php
---

在Weathermap.class.php中，定义了一个function叫LoadPlugins，读取lib/datasources/下的php类。其中就有WeatherMapDataSource_rrd.php。其中定义了Init、Recognise和ReadData三个方法。明显是ReadData函数来读取rra数据，具体方法为调用管道，运行rrdtool命令。

命令如右：rrdtool fetch *.rrd AVERAGE --start now-800 --end now

然后是对命令的结果进行分析。可以先运行一下看看效果：

[raochenlin@cacti datasources]$ date +%s;/usr/local/rrdtool-1.2.18/bin/rrdtool fetch /www/cacti/rra/10_168_168_130_traffic_in_2866.rrd AVERAGE --start now-800 --end now
1290704787
traffic_out          traffic_in

1290704100: 4.8623533333e+01 2.2821386667e+02
1290704400: 4.0663000000e+01 1.9051346667e+02
1290704700: 3.5332000000e+01 2.3380053333e+02
1290705000: nan nan

由此可见数据是300s一采集，所以当设定start是-800的时候，就会取比800大的离800最近的300的倍数，即900之间的数据。
