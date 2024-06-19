---
layout: post
theme:
  name: twitter
title: 《SUSE Linux Enterprise Desktop System Analysis and Tuning Guide》读书笔记
date: 2011-04-05
category: linux
---

这是一本比上篇提到的老书新很多、厚很多的调优指南。虽然至今没用过suse，但同是linux内核，与redhat差距不算太大。目前只打印并看到了systemtap章节，感觉很多内容说的比上本书细致的多，继续做笔记~
<!--more-->
1 General Notes on System Tuning
1.2 Rule Out Common Problems
检查/var/log/warn和/var/log/messages中的异常条目；
用top或ps命令检查是否有进程吃了太多CPU和内存；
通过/proc/net/dev检查网络问题；
用smartmontools检查硬盘IO问题；
确认后台进程都是在系统负载较低的时候运行的，可以通过nice命令调整其优先级；
一台服务器运行太多使用相同资源的服务的话，考虑拆分；
升级软件。
2 System Monitoring Utilities
2.1 Multi-Purpose Tools
2.1.1 vmstat
第一行输出显示的从最近一次重启以来的平均值
各列说明：
r 运行队列中的进程数。这些进程等待cpu的空闲以便执行。如果该数值长期大于cpu核数，说明cpu不足；
b 等待除了cpu以外的其他资源的进程数。通常是IO不足；
swpd 已用swap空间，单位KB；
free 未用内存空间，单位KB；
inact 可以回收的未用内存空间，只有当使用-a参数时才显示——建议使用该参数；
active 使用中且没有回收的内存空间，同样只在-a时显示；
buff 内存中的文件缓冲空间；相反，-a时不显示；
cache 内存中的页缓存空间；-a不显示；
si 每秒从内存移动到swap的数据大小，单位KB；
so 每秒从swap移动到内存的数据大小，单位KB，以上两个数长期偏大的话，机器需要加内存；
bi 每秒从块设备中获取的块数量——注意swap也是块设备，包含在内！
bo 每秒发送到块设备的块数量，同样包括swap；
in 每秒中断数，数值越大说明IO级别越高；
cs 每秒文本交换数，这个代表内核从内存中某进程中提取替换掉另一个进程的可执行代码——茫然？？
us 用户空间的cpu使用率；
sy 系统空间的cpu使用率；
id cpu时间中的空闲比——就算它是0，也不一定就是什么坏事，还得看r和b两个数值来判断；
wa 如果这个数不等于0，那说明系统吞吐在等待IO。这或许是不可避免的。比如如果一个文件是第一次被读取（即没有缓存），那同时的后台写必然挂起。这个数也是硬件瓶颈的一个指标（网络或者磁盘）。最后，还有可能是虚拟内存管理上的问题；
st cpu用在虚拟管理上的比例。
2.1.2 System Activity Information: sar and sadc
sadc其实就是在/etc/cron.d中添加的任务。原始数据写入/var/log/sa/saDD中，报告数据写入/var/logs/sar/sarDD中。默认配置，数据每10分钟一收集；报告每6小时一收集。详见/etc/sysstat/sysstat.cron；数据收集脚本是/usr/lib64/sa/sa1；数据报告脚本是/usr/lib64/sa/sa2；有必要的话可以自己用这两个脚本收集性能数据。
sar -f指定特定的数据文件出报告
sar -P指定某一个CPU出报告
sar -r显示内存信息：kbcommit和%commit显示了当前工作负载下可能需要的最大内存（含swap）；
sar -B显示内核页信息：majflt/s显示了每秒钟有多少页从硬盘（含swap）读入内存，这个数太大意味着系统很慢，而且内存不足；%vmeff显示了页扫描(pascand/s)及其相关的缓冲重用率(pgsteal/s),用以衡量页面回收的效率，数值接近100说明所有so的页都重用了，接近0说明没有被扫描的页，这都很好，但不要在0-30%之间。
sar -d显示块设备信息，最好加上-p显示设备名；
sar -n显示网络信息，包括DEV/EDEV/NFS/NFSD/SOCK/ALL
2.2 System Information
2.2.1 iostat
-n显示nfs；
-x显示增强型信息；
2.2.3 pidstat
-C "top"显示命令名中包括top字符串的目标。
2.2.5 lsof
无参数：打开的所有文件
-i：网络文件
2.2.6 udevadm
本工具只有root可以使用
2.3 Processes
2.3.2 ps
显示具体某进程：ps -p $(pidof ssh)
显示格式和排序：ps ax --format pid,rss,cmd --sort rss
显示单独进程：ps axo pid,$cpu,rss,vsz,args,wchan,etime
显示进程树：ps axfo pid,args
2.3.4 top
默认每2秒钟一刷新；
显示一次即退出：-n 1
shift+p——以CPU使用率排列(默认)；
shift+m——以常驻内存排列；
shift+n——以进程号排列；
shift+t——以时间排列；
2.4 Memory
2.4.1 free
free -d 1.5——每1.5秒一刷新数据
2.4.3 smaps
在/proc/${pid}/smaps中看到的是进程当前的内存页数量，即除掉共享内存以外的真正进程使用的内存大小。
2.5 Networking
2.5.1 netstat
-r路由；-i网卡；-M伪装链接；-g广播成员；-s信息
2.5.2 iptraf
iptraf -i eth0 -t 1 -B -L iptraf.log
eth0网卡一分钟内的信息，后台收集，记入iptraf.log中。
2.6 The /proc File System
/proc/devices 可用设备
/proc/modules 已加载内核模块
/proc/cmdline 内核命令行
/proc/meminfo 内存使用详细信息
/proc/config.gz 内核当前运行配置的压缩文件
详细说明见/usr/src/linux/Documentation/filesystems/proc.txt
执行的进程和库文件以及他们在内存的地址信息见/proc/***/maps文件。

