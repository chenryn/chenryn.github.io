---
layout: post
theme:
  name: twitter
title: weathermap-cacti-plugin学习(1)
date: 2010-11-24
category: monitor
tags:
  - cacti
  - php
---

weathermap是一个利用php的gd库画图的程序，它可以自主运行，但更多情况下是作为cacti等监控工具的插件，通过rra数据库获取数据完成绘图。其官网地址如右：<a href="http://www.network-weathermap.com">http://www.network-weathermap.com</a>

正常情况下，其link的color是由浅到深，当链路接近满载时，显示为鲜红色~然而这个设定遗漏了一个更加严重的情况——链路中断！在完全没有流量的情况下，weathermap应该会按照默认的0%处理——显示为白色（有+1的黑色边框）。

当然，这么可怕的事情，肯定会有多种手段来完成报警，不至于靠人眼盯着weathermap来汇报。但毕竟算是个功能上的缺失。

很巧，在zenoss（和cacti类似的另一款监控软件）的wiki上，看到有网友修改的perl版的weathermap，网址如右：<a href="http://community.zenoss.org/docs/DOC-2543">http://community.zenoss.org/docs/DOC-2543</a>。其配置文件中的WIDTH标签，比php的多出了<%status-width(device name,component name)%>配置，其解释说“draw link with width 0 if it is down otherwise draw it with width_ok width”。相关代码如下：
```perl
while($line=~m/<%status-width([^%]+)%>/)
{
my $tmp;
$tmp=$1;
my $res;
#WidthIfOK, device, port
if ($tmp=~m/\((.+),(.+),(.+)\)/)
{
my $url=get_device_url($2);
$res=get_port_status("$url/$3");
if ($res==1) #OK
{
$res=$1; #default width
}
else
{
$res=0;
}
}
else
{
die ("Bad format $line");
}
if ($line!~s/<%status-width([^%]+)%>/$res/)
{
die ("Error 1");
}
}
```
思路是通过wget数据获取状态，一旦错误就至width为0，否则读取正常设定值绘图。

在原版的php中相关部分如下：
```php
if (preg_match("/^\s*WIDTH\s+(\d+)\s*$/i", $buffer, $matches))
{
if ($last_seen == 'LINK')
{
$curlink->width=$matches[1];
$linematched++;
}
else // we're talking about the global WIDTH
{
$this->width=$matches[1];
$linematched++;
}
}
```
显然只要在这里加上一个else{}就可以了。

至于如何判定链路中断，有待继续学习~是外挂一个ping？或者读取rra中的数值？下一步先看懂Weathermap.class.php是怎么读取rra数值的吧~

（题外话，在baidu该字眼的第一页结果，看到中南民族大学的校园网cacti页面。他们居然开放匿名访问，甚至settings都能点开，无语~网址如右：<a href="http://210.42.159.3/cacti/plugins/weathermap/weathermap-cacti-plugin.php">http://210.42.159.3/cacti/plugins/weathermap/weathermap-cacti-plugin.php</a>）
