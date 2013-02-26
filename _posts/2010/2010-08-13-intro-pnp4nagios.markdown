---
layout: post
title: nagios绘图
date: 2010-08-13
category: monitor
tags:
  - nagios
  - rrdtools
---

nagios默认command中，有个未开启的process_performance_data。可以开启它来保存数据，然后提供给rrdtools绘图。

下载pnp插件包，官网是<a href="http://www.pnp4nagios.org/">http://www.pnp4nagios.org</a>，和cacti一样，保证有lamp、rrdtool（低版本的还要GD），然后和其他插件一样./configure && make && make all && make install && make install-config && make install-init就行了。
然后修改nagios.cfg如下：

process_performance_data=1
service_perfdata_command=process-service-perfdata
host_perfdata_file=/usr/local/nagios/var/host-perfdata

修改commands.cfg如下：

define command{
    command_name          process-service-perfdata-file
    command_line          $USER1$/process_perfdata.pl
}
define command{
    command_name          process-host-perfdata-file
    command_line          $USER1$/process_perfdata.pl
}

再修改pnp/process_perfdata.cfg-sample，设定好rrdtool等的路径，另存为process_perfdata.cfg。重启nagios即可。

过一会图就出来了，不过我自己写的两个脚本，随意检测正常，页面上也看到了输出值，就是没图……报出来***.rrd not found。进目录一看，其他图都创建出来了，就自定义脚本的没有……

咬牙看了会include/function.inc.php，发现php在调用rrdtool create的时候，使用的直接就是$data[1]['*']这样的数据，整个functions里都没有看到怎么匹配切割数据的部分。可是看页面上nagios自带的command输出，也没什么明显标记啊？

上服务器看脚本，试着手动运行了一次check_http，发现输出结果比页面上显示的还多了一串“| time=0.003329s;5.000000;10.000000;0.000000 size=1576B;;;0”！这个明显有着固定的格式！

然后在页面上点开check_http看，发现在报警状态“Status Information:  HTTP OK HTTP/1.0 200 OK - 1576 bytes in 0.003 seconds”下还有一行“ Performance Data: time=0.003329s;5.000000;10.000000;0.000000 size=1576B;;;0”。原来如此……

修改shell脚本的echo内容，也照葫芦画瓢的加上了“| port ${PORT}=${PORT_CONN};${WARNING};${CRITICAL};;”等五分钟后，再点开pnp图，果然出现了！

