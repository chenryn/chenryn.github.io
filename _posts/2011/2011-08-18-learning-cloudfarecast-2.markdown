---
layout: post
title: CloudForecast学习笔记(二)
date: 2011-08-18
category: perl
---

接下来看radar部分，也就是探测主程序cloudforecast_radar，其中主要就是调用CloudForecast::Radar中的run()函数。
首先还是惯例，调用ConfigLoader模块加载配置文件；
然后是%SIG信号的定义，用来之后自动重运行的；
然后一个while true死循环：
1、循环里用select(undef,undef,undef,0.5)实现一个0.5秒的sleep；
2、第一个if语句，用来判断是否是父进程，并使用无阻塞的waitpid($pid,WNOHANG)等待子进程完成——即$kid==-1；
3、第二个if语句，用来强制退出死循环，条件是收到%SIG信号；
4、第三个if语句，确认当前时间超过计划中的执行时间（即离上次执行时间最近的整5分钟点），开始执行探测——采用fork()派生子进程。
5、子进程内容是从之前获取的配置文件内，轮询每一台设备，最终调用run_host()函数执行。
然后又是两个if语句，接在while里的last之后，等待子进程全部完成的。

接下来看run_host()函数，其实就是new了一个CloudForecast::Host对象，并调用其run()函数。
这个run()函数，就是根据config里的resource调用相应的CloudForecast::Data::*，最后到CloudForecast::Data里的call_fetch()函数。ok，这个函数上一篇已经看过了。
