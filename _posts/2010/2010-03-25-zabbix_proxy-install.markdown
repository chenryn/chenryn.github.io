---
layout: post
theme:
  name: twitter
title: zabbix_proxy部署
date: 2010-03-25
category: monitor
---

_continue_
    
zabbix作为分布式监控系统，不试试实在可惜。好在做起来也简单。    
首先要求编译时有enable-proxy参数，这个已经有了；    
然后修改zabbix_proxy.conf，和zabbix_server.conf相同的修改（DB等）就不再说了：    
Server=要写最上层zabbix的ip    
Hostname=要写独一无二的，在最上层zabbix的web配置上要用    
ConfigFrequency=这个是配置同步时间差，设短一点，默认3600太长    
TrapperTimeout=超时时间，设短一点，默认300，最好不超过30    
    
然后在最上层的zabbix的web界面上添加proxy即可。administrator-DM-proxy-Add，填入刚才独一无二的那个Hostname即可。    
    
Add Host的时候，选择proxy——host里agentd.conf的Server也必须是相应proxy的ip才行。    
_To_be_continued_    
