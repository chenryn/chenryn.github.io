---
layout: post
title: nagios性能监控
date: 2010-10-19
category: monitor
tags:
  - nagios
---

nagios自带有性能监控工具nagiostats，安装在nagios路径的bin/下。直接运行即可看到主机、服务的检测频率，故障数量及比例等。举例如下：

Nagios Stats 3.0.3
Copyright (c) 2003-2008 Ethan Galstad (www.nagios.org)
Last Modified: 06-25-2008
License: GPL

CURRENT STATUS DATA
------------------------------------------------------
Status File:                            /usr/local/nagios/var/status.dat
Status File Age:                        0d 0h 0m 9s
Status File Version:                    3.0.3

Program Running Time:                   6d 17h 48m 34s
Nagios PID:                             14400
Used/High/Total Command Buffers:        0 / 0 / 4096

Total Services:                         1343
Services Checked:                       1343
Services Scheduled:                     1343
Services Actively Checked:              1343
Services Passively Checked:             0
Total Service State Change:             0.000 / 11.580 / 0.009 %
Active Service Latency:                 0.001 / 4.541 / 0.451 sec
Active Service Execution Time:          0.007 / 6.723 / 0.202 sec
Active Service State Change:            0.000 / 11.580 / 0.009 %
Active Services Last 1/5/15/60 min:     379 / 927 / 1178 / 1343
Passive Service Latency:                0.000 / 0.000 / 0.000 sec
Passive Service State Change:           0.000 / 0.000 / 0.000 %
Passive Services Last 1/5/15/60 min:    0 / 0 / 0 / 0
Services Ok/Warn/Unk/Crit:              1343 / 0 / 0 / 0
Services Flapping:                      0
Services In Downtime:                   0

Total Hosts:                            239
Hosts Checked:                          239
Hosts Scheduled:                        239
Hosts Actively Checked:                 239
Host Passively Checked:                 0
Total Host State Change:                0.000 / 0.000 / 0.000 %
Active Host Latency:                    0.014 / 5.048 / 2.766 sec
Active Host Execution Time:             4.006 / 5.095 / 4.018 sec
Active Host State Change:               0.000 / 0.000 / 0.000 %
Active Hosts Last 1/5/15/60 min:        223 / 238 / 239 / 239
Passive Host Latency:                   0.000 / 0.000 / 0.000 sec
Passive Host State Change:              0.000 / 0.000 / 0.000 %
Passive Hosts Last 1/5/15/60 min:       0 / 0 / 0 / 0
Hosts Up/Down/Unreach:                  239 / 0 / 0
Hosts Flapping:                         0
Hosts In Downtime:                      0

Active Host Checks Last 1/5/15 min:     183 / 444 / 1135
Scheduled:                           183 / 444 / 1133
On-demand:                           0 / 0 / 2
Parallel:                            183 / 444 / 1134
Serial:                              0 / 0 / 0
Cached:                              0 / 0 / 1
Passive Host Checks Last 1/5/15 min:    0 / 0 / 0
Active Service Checks Last 1/5/15 min:  494 / 1082 / 3209
Scheduled:                           494 / 1082 / 3209
On-demand:                           0 / 0 / 0
Cached:                              0 / 0 / 0
Passive Service Checks Last 1/5/15 min: 0 / 0 / 0

External Commands Last 1/5/15 min:      0 / 0 / 0

&nbsp;
