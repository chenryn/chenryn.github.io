---
layout: post
title: mysql状态报表工具
date: 2010-11-12
category: database
tags:
  - MySQL
---

最近学习mysql，从监控的角度出发，然后发现了一个很不错的个人网站<a href="http://hackmysql.com">http://hackmysql.com</a>，啧啧，看这名字就NB烘烘滴~
网站的tools列表提供了一系列站长认为很不错的mysql工具，其中有他自己早年写的四个perl，也有他目前所在公司出品的工具（大名鼎鼎的Maatkit，据说80%的国外mysqlDBA使用它，国内有大头刚曾经写过14篇介绍文章，以后有时间再看，地址如下：<a href="http://search.chinaunix.net/bbs.php?q=Maatkit&amp;username=&amp;st=title&amp;bbs=1&amp;forums=136&amp;page=1">http://search.chinaunix.net/bbs.php?q=Maatkit&amp;username=&amp;st=title&amp;bbs=1&amp;forums=136&amp;page=1</a>）。
在国内目前的技术文章来看（即百度可见范围内），比较常见的两个工具正是该站提供的，一个是状态报告工具mysqlreport，一个是日志分析工具mysqlsla。
今天先说mysqlreport，安装很简单：wget <a href="http://hackmysql.com/scripts/mysqlreport">http://hackmysql.com/scripts/mysqlreport</a>
要使用它，首先需要有几个perl模块：DBI和DBD::mysql。CPAN安装即可。需要注意的是，因为DBD::mysql的安装过程中需要调用mysql_config，如果机器上没有mysql或者mysql的bin不在PATH里，都会报错。这时候退出安装mysql，然后到.cpan/里去手动perl Makefile.PL --with-mysql_config=/path/to/mysql_config安装吧~~
使用方法也有--help的详尽说明，大抵是--host/--user/--password，比较好玩的是还提供了--relative/--report-count用来短时间段内的定时报告。
报告包括：
key buffer的使用率和命中率；
请求的分类比例（QC Hits和DMS越多越好，Com_最好不要超过3%）及具体情况；
慢查询情况（最好一个没有）；
全表查询和排序情况（这个越少越好）；
表锁等待情况（最好没有）；
表使用和命中率情况（尽量命中的好）；
连接情况（适中即可）；
线程复用情况；
[然后是InnoDB引擎的一些]
锁等待；
读写速度；
行操作情况

mysqlreport2008年之后就停止了更新，一部分人则开始采用tuning-primer.sh收集报表。这个shell脚本直接利用mysql客户端登陆服务器后show status然后进行运算，除了和mysqlreport极为类似的报表外，还采用不同颜色显示提供了作者的优化建议，边看边学习，很不错，下载地址如下：<a href="http://www.day32.com/MySQL/tuning-primer.sh">http://www.day32.com/MySQL/tuning-primer.sh</a>
这个网站同样提供了对mysql主从同步的脚本和监控脚本，都是shell脚本~~

最后，还要表扬一下ifeng的运维童鞋，他们用php完成一个功能介乎mysqlreport和tuning-primer之间的mysql状态报表网页，目前版本是mysqlmonitor1.0.0（不过下载链接坏了……）。其中很多推荐配置中文说明，不过在“具体情况具体分析”方面还不够智能，所有建议都是统一在4G内存mysql服务器的假设条件下给出的，也没有对报表数据进行阀值触发。
