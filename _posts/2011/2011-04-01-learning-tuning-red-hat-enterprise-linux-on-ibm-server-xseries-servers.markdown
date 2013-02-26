---
layout: post
title: 《Tuning Red Hat Enterprise Linux on IBM server xSeries Servers》读书笔记
date: 2011-04-01
category: linux
---

一本很老的书，还是RHEL3时代的，在陪GF的空隙一点点读完，把笔记整理一下发在这里，只包括自己不知道或者说容易忘记的内容，不代表调优指南。<!--more-->
1 Tuning the operating system
1.1 Disabling daemons
关闭不必要的后台进程。RHEL3中，默认启动的后台进程有：
apmd 高级电源管理
autofs 自动挂载
cups 通用UNIX打印机系统
hpoj 惠普打印机支持
isdn 调制解调器
netfs nfslock portmap NFS支持
pcmcia PCMCIA支持
rhnsd 自动升级
sendmail 邮件转发程序
xfs 桌面程序
1.2 Shutting down the GUI
runlevel:
0 halt立刻关机immediately shut down
1 single单人
2 multi-user without NFS（这个说明和一般的说法不太一样~）
3 full multi-user
5 X11
6 reboot
修改/etc/inittab如下：
id:3:initdefault:		#runlevel
#4:2345:respawn:/sbin/mingetty tty4		#关闭多余控制台
注意：留3个，以免在被攻击的时候自己反而进不去了！
1.4 Changing kernel parameters
/proc/loadavg 系统负载1/5/15分钟
/proc/stat 内核状态：进程/swap/磁盘IO
/proc/cpuinfo CPU信息
/proc/meminfoo 内存信息
/proc/sys/fs/* linux可用文件数及磁盘配额
/proc/sys/kernel/* 进程号范围/系统日志级别
/proc/sys/net/* 网络细节
/proc/sys/vm/* 内存缓冲管理
1.7 Tuning the processor subsystem
CPU超线程注意事项:
注意使用SMP的kernel
实际CPU数越多，超线程意义越小：
2核：提升15-25%
4核：提升1-1%
8核：提升0-5%
1.8 Tuning the memory subsystem
如果决定调整/proc/sys/vm/*的参数，最好一次只调整一个。
vm.dbflush前3个参数分别为：
nfract 在buffer被转存到disk前允许的最大buffer比率
ndirty 将buffer转到disk时一次允许操作最大的buffer数
nfract_sync 转存时允许buffer中dirty数据的最大比率
vm.kswapd
tries_base 一次swap传输时的pages数。如果swapping较大，适当增加该值
tries_min kswapd运行时交换的pages的最小数
swap_cluster kswapd一次写入pages的数。太小会增加IO次数，太大又要等待请求队列
1.9 Tuning the file subsystem
磁盘访问速度是ms级别的，而内存是ns，PCI是us。
磁盘IO是最关键的问题服务器举例：
文件/打印服务器：所有数据从磁盘读取
数据库服务器：大量IO，在内存和磁盘间交换数据
磁盘IO不是最关键的问题服务器举例：
邮件服务器：网络状况才是最关键的。
web服务器：网络和内存才是最关键的.....
1.9.5 The swap partition
创建多个swap区有助于提升swap性能
通常情况，多个swap采用顺序读写，即只有/etc/fstab中排名在前的swap区耗尽的情况下，才会使用下一个swap区；
可以在fstab中定义优先级，类似"/dev/sda2 swap swap sw,pri=5 0 0"的格式；
相同优先级的swap区，系统会并发使用，不同优先级之间依然要等待耗尽！——另外，如果相同优先级的swap区有一个性能较差，会连带影响整个swap性能。
1.10 Tuning the network subsystem
网络问题经常会导致其他伴生问题。比如：块大小太小会给CPU利用率带来显著影响；TCP连接数过多会带来内存使用率的急速上升……
经常被打开的net.ipv4.tcp_tw_reuse和net.ipv4.tcp_tw_recycle的作用：缓存TCP交互中的客户端信息，包括交互时间、最大段大小，阻塞窗口。详见RFC1644。
net.ipv4.tcp_fin_timeout可以缩短TCP建连时最后发送FIN序列的时间，以便快速释放内存提供给新进连接请求。但是修改这个的时候也要谨慎，因为由此导致的死套接字数量可能引起内存溢出！
net.core.wmem_max/net.core.rmem_max定义在每个TCP套接字创建时划分的内存大小，推荐设置8MB。
net.ipv4.tcp_wmem/net.ipv4.tcp_rmem的最后一个数字不能大于上面core的定义。
net.ipv4.tcp_max_syn_backlog队列存放半连接。这些连接可能是因为客户端的连接异常，也可能仅仅是因为服务器负载太高导致。除了半连接，这个配置对防范拒绝服务攻击也有效。
net.ipv4.ipfrag_low_thresh/net.ipv4.ipfrag_high_thresh规范ip碎片，一旦触底，内核会开始丢包。这对于NFS和samba等文件服务器很重要，建议设置为256和384MB。
2 Tuning tools
2.3 top
STAT:S=SLEEPING,R=RUNNING,T=TRACED/STOPPED,D=INTERRUPTIBLE SLEEP,Z=ZOMBIE
2.3.1 Process priority and nice levels
优先级从19（最低）到-19（最高），默认是0。启动进程时指定nice -n 19 command，启动后改变renice 19 command
2.4 iostat
tps:transfers per second,多个单独的IO请求，可以组合在一次transfer请求中。
Blk_read/s,Blk_wrtn/s:每秒的读写块个数。block大小和transfer大小一样各不相同。一般是1、2、4KB，采用如下命令查看：dumpe2fs -h /dev/sda1 | grep -F 'Block Size'
2.5 vmstat
Process：r:等待运行的进程数，b:不可中断睡眠中的进程数
Swap：单位是KBps
CPU：us:非内核时间，包括user和nice，id:在linux2.5.41前，这个数值包括了IOwait时间在内……
2.11 ulimit
-H和-S分别是hard和soft，开机启动指定的话，修改/etc/security/limits.conf即可。
2.12 mpstat
用来在多CPU的机器上查看每个CPU的情况。
3. Analyzing performance bottlenecks
3.1 Identifying bottlenecks
快速调优策略：
a. 了解你的系统；
b. 备份系统；
c. 监控、分析系统性能；
d. 缩小瓶颈，找出根源；
e. 解决瓶颈的时候一次只修改一个地方；
f. 返回c步骤继续，直到满意。
3.1.1 Gathering information
在收到“服务器出问题了”的报警时，提出下列问题，可以更加有效地收集信息进行故障定位：
Q:服务器的完整描述？包括：模块、使用时长、配置、外围设备、操作系统版本号……
Q:能准确描述一下问题所在么？包括：症状表现、各种错误日志记录……
Q:问题是谁碰到/发现的？一个人、某些特定的人群，还是所有的用户？由此可以大概猜测问题是网络、应用还是客户电脑。另外：性能问题可能不会立刻从服务器反应到客户端上来，因为网络延迟经常会覆盖掉其他问题。这个延迟包括网络设备，也包括其他服务器提供的网络服务，比如域名解析~
Q:问题可以再现么？所有可以再现的问题都是可以解决的！
重现故障的步骤是什么？这可以协助你在测试环境完成调优工作。
问题是持续发生的么？如果是断续发生的，赶紧找出让它重现的办法，最好就是能按你的剧本指令重现……
问题是不是周期性的固定某个时间发生？查查那时候是不是有人登陆了？尝试梗概系统，看问题会重现么？
问题真的很不常见？如果真是如此，那只能说rp有问题了，事实上，绝大多数问题都是可重现的~对没法重现的，那就出网管绝招：reboot、然后更新升级驱动和补丁。
Q:问题什么时候开始的？逐渐显现还是突然爆发？如果是逐渐，那应该是积累出来的；如果是突然，那考虑是不是外设做了改动。
Q:服务器是不是有变动，或者客户端的使用方法变了？
Q:事情紧急么？要求几分钟内搞定还是未来几天？
3.1.2 Analyzing the server's performance
在任何排障动作前，牢记备份！！
有必要为服务器创建一份性能日志，内容包括：进程、系统、工作队列、内存、交换页、磁盘、重定向、网卡……
3.2 CPU bottlenecks
动态应用/数据库服务器，CPU常常是瓶颈，但实际经常是CPU在等待其他方面的响应。
3.2.1 Finding CPU boottlenecks
注意：同时不要运行多个工具，以免给CPU增加负载
3.2.2 SMP
进程在CPU之间进行切换时需要消耗一点的时间，所以绑定CPU比较有用。
3.2.3 Performance tuning options
关闭非必须进程；调成优先级；绑定CPU；CPU主频，是否多核；更新驱动；
3.3 Memory bottlenecks
free命令参数-l -t -o，分别表示low/high，total，old（不显示buffer信息）
3.3.2 Performance tuning options
调整页大小，默认是4/8KB；限定user资源limits.conf；……
3.4 Disk bottlenecks
常见问题：一、硬盘数太少；二、分区数太多，导致磁头寻址时间变大。
3.4.1 Finding disk bottlenecks
写缓冲；磁盘控制器负载；网络延时导致响应慢；IO等待队列
随机读写还是顺序读写？单次IO大还是小？
表3-2
磁盘转速 latency seek-time random-access-time IOPS Throughout
15000    2ms      3.8ms      6.8ms                    147  1.15MBps
10000    3ms      4.9ms      8.9ms                    112  900KBps
7200     4.2ms    9ms        13.2ms                    75   600KBps
在一个大概70%读30%写的随机IO型正常负载的服务器上，采用RAID10比RAID5能提高50-60%的性能。
 打开文件太多时，会因为寻址时间太长导致响应的变慢
iostat的指标：
%util 被IO请求消耗的CPU比例
svctm 完成一个请求的平均时间，单位ms
await 一个IO请求等待服务的平均时间，单位ms
avgqu-sz 平均队列长度
avgrq-sz 平均请求大小
rrqm/s 发送到磁盘的每秒合并读请求数
wrqm/s 发送到磁盘的每秒合并写请求数
3.4.2 Performance tuning options
顺序读写换磁头；随机读写加磁盘；用硬件RAID卡；加内存
3.5 Network bottlenecks
    3.5.2 Performance tuning options
    检查路由配置；子网；网卡速率；TCP内核参数；换网卡；bonding
4 Tuning Apache
4.1 Gathering a baseline
吞吐量：每秒请求数和每秒传输字节数；请求处理响应时间……
4.5 Operating system optimization
文件打开数；进程数；文件访问时间——不记录atime的作用是消减IO峰值！
4.6 Apache 2 optimizations
如果文件是通过NFS方式发布的，apache不会采用sendfile方式缓存文件，配置文件请选择“EnableSendfile Off”！
4.6.1 Multi-processing module directives
经常需要重启的，加大StartServer；
负载较大的，加大MinSpareServers到25，MaxSpareServers到125；
MaxClients最大只能是256，内存不足时应该减少；
4.6.2 Compression of data
默认的6级压缩比，可以带来72%的带宽减小。太高级别压缩，对CPU有影响。
在测试中，启用压缩的apache带宽减小70%；cpu负载上升87%到饱和状态，能同时处理的客户端请求数降到三分之一。
vary头的作用：告知代理服务器对支持压缩的客户端只发送压缩后的内容。
apache2只在客户端请求包含Accept-encoding: gzip和Accept-encoding: gzip, deflate的时候才压缩数据。
4.6.3 Logging
使用WebBench的时候，一般会有2%的请求是404的，这可能导致error_log迅速变大！
5 Tuning database servers
5.1 Important subsystems
CPU：
数据库都是多线程的，最好使用16核以上CPU，2级缓存相当重要，命中率最好在90%以上；
内存：
缓冲是数据库最重要的部分。编译内核时请确认CONFIG_HIGHMEM64G_HIGHPTE=y这项。
磁盘：
数据库会有大量的磁盘IO以完成数据在内存和硬盘的交换。一般每个xeon的CPU需要对应10块高速硬盘，最好能有50块10000转的磁盘。IBM的xSeries 370使用450块10000转磁盘以达到最大吞吐量——每分钟40000次交换。

笔记到此为止。之后的内容是DB2的调优，samba、ldap、lotus章节，就没看了……
