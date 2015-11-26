---
layout: post
title: pnp4nagios的模板问题(2)
date: 2010-11-18
category: monitor
tags:
  - nagios
  - rrdtools
  - php
---

接上篇。结尾时找到的url确实就是解决这个问题的。我错怪作者鸟~~

在 `nagios/etc/pnp/check_commands` 文件夹下，可以添加 `%check_command%.cfg` 配置文件，以定义pnp在使用模板时的一些参数。在我的应用环境下，只需要添加如下一个 `check_nrpe.cfg` 即可：

    CUSTOM_TEMPLATE = 1   #使用命令的第一个参数做自定义模板名
    DATATYPE = GAUGE       #数据类型为即时数值
    USE_MIN_ON_CREATE = 0    #绘图数据最小值为0，用来排除某些错误溢出导致的负值

然后就可以进 `nagios/share/pnp/templates/` 下去创建自己需要的模板了。仿照cacti的样子写个loadavg的如下：
```php
<?php
$opt[1] = "--vertical-label Load -l0  --title \"CPU Load for $hostname / $servicedesc\" ";
$def[1] =  "DEF:var1=$rrdfile:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:var2=$rrdfile:$DS[2]:AVERAGE " ;
$def[1] .= "DEF:var3=$rrdfile:$DS[3]:AVERAGE " ;
$def[1] .= "CDEF:total=var1,var2,+,var3,+ " ;
$def[1] .= "HRULE:$WARN[1]#FFFF00 ";
$def[1] .= "HRULE:$CRIT[1]#FF0000 ";
$def[1] .= "AREA:var1#FFD700:\"load 1 \" " ;
$def[1] .= "GPRINT:var1:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var1:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var1:MAX:\"%6.2lf max\\n\" ";
$def[1] .= "AREA:var2#7FFF00:\"Load 5 \":STACK " ;
$def[1] .= "GPRINT:var2:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var2:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var2:MAX:\"%6.2lf max\\n\" " ;
$def[1] .= "AREA:var3#FF0000:\"Load 15\":STACK " ;
$def[1] .= "GPRINT:var3:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var3:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var3:MAX:\"%6.2lf max\\n\" " ;
$def[1] .= "LINE1:total#000000 " ;
?>
```

采用DEF方式定义数据，CDEF方式计算总和，HRULE画水平线，AREA画涂层，LINE画连线(有1/2/3种粗细)，STACK累加数值绘图效果，GPRINT计算并显示数据。

只画一个图就都是$def[1]，如果需要两个图就是$def[2]，依次类推，不过页面上的Datesource是读取的*.xml文件中的<NAME>，如果合并数据绘图，显示就会有问题，所以最好就把所有数据都画一张图里。比如网卡流量。用CDEF取反，我不知道RPN中有没有特定函数，简单的采用了0,var,-方式，将部分数据倒到x轴下方~~

如果不是STACK的话，需要注意一点，AREA方式是不透明的，单纯的图层覆盖，所以一定要把最大的值放在最前面绘制，然后才能有效果。像流量这种没谱的事情，最好就采用LINE方式~~

目前我绘制的load、conn、flow三个rra如下：

![load](/images/uploads/load.jpg)

![conn](/images/uploads/conn.jpg)

![flow](/images/uploads/flow.jpg)

