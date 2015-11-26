---
layout: post
title: 通过snmp协议监控NetApp
date: 2010-12-22
category: monitor
tags:
  - snmp
  - NetApp
---

NetApp作为专业存储，用起来还是比较让人放心的，不过放心不代表放手不管，一些重要的监控还是要做的。比如基本的CPU负载、网卡流量、磁盘使用率，作为数据存储特别关注的IOPS、DiskIO（因为有cache的原因，所以NetIO和DiskIO是不同时的，单从网卡进出不能判定磁盘的真实读写）。

从google中找到了NetApp的MIBtree，见<a href="https://support.ipmonitor.com/mibs/NETWORK-APPLIANCE-MIB/tree.aspx">https://support.ipmonitor.com/mibs/NETWORK-APPLIANCE-MIB/tree.aspx</a>或<a href="http://www.mibdepot.com/cgi-bin/getmib3.cgi?abc=0&amp;n=NETWORK-APPLIANCE-MIB&amp;r=netapp&amp;f=netapp_1_4.mib&amp;t=tree&amp;v=v1&amp;i=0&amp;obj=cp">http://www.mibdepot.com/cgi-bin/getmib3.cgi?abc=0&amp;n=NETWORK-APPLIANCE-MIB&amp;r=netapp&amp;f=netapp_1_4.mib&amp;t=tree&amp;v=v1&amp;i=0&amp;obj=cp</a>

（多贴一个，省的万一哪个站挂了……）

CPU等项没什么问题，问题在于IO的获取。
与普通服务器的流量一样，很明显的看到了miscNfsOps、miscNetRcvdKB和miscNetSentKB三个值。我们可以很简单的通过后个值的差值运算出速率。但如果单取一个值的时候，会发现一个很诡异的情况，见下：

# snmpwalk -v 1 -c public 10.10.10.118 .1.3.6.1.4.1.789.1.2.2.3 | awk '{print $NF}'
-1948753579

居然是个负值！

难道是对这个MIB的理解有问题？可通过如下命令计算的结果，和通过交换机端口获取的流量却基本符合了：

a=`snmpwalk -v 1 -c public 10.10.10.118 .1.3.6.1.4.1.789.1.2.2.3 | awk '{print $NF}'`;sleep 10;snmpwalk -v 1 -c public 10.10.10.118 .1.3.6.1.4.1.789.1.2.2.3 | awk '{print ($NF-"'$a'")*8/10"Kbps"}'
12364.8Kbps

虽然数值都变负了，但差量还是对的……汗，如果通过AVERAGE方式取这个差值绘图，倒不要紧，如果通过普通的流量Counter方式，这个图全反过X轴去了应该~

这个情况很容易让我想到用cacti获取网卡流量时的配置，如果选用默认的32bits绘图时，在流量较大时也会出现这类负值或者干脆画不出来的情况。

其次，DiskIO没有和Net一样的MIB；但net、disk和ops都有一对miscHigh***/miscLow***的数值。

这对值怎么用？MIB上的解释看起来超级茫然：
miscLowNfsOps：The total number of Server side NFS calls since the last boot.  This object returns the least significant 32 bits of the value.
miscHighNfsOps：The total number of Server side NFS calls since the last boot.  This object returns the most significant 32 bits of the value.

通过度娘了解了一下least significant bit和most significant bit的概念，原来LSB和MSB是在底层开发时的概念，因为2进制的字串比较长，所以通过MSB和LSB的命名方式来标明字串的高位（普通PC和MAC在存数据的时候顺序是反的，所以必须标记，还有其他原因，比如用MSB的1、0来表示正负数等）

那么这个most significant 32bits也就理解了~~就是从高位开始往低算的32位。least反过来……合并起来就是64位的完成数据了……2进制数的合并，也就是说用$MSBs * 2**32 + $LSBs。My God~

最后在zenoss的maillist上看到了相同的问题，其中网友的回答是：NetApp使用的snmp协议是v1版本，无法直接提供64bits的计数，只能变通一下，改用这种拆分方式了。

最后，举例一个监控ops的perl脚本。原脚本是centreon项目提供的，删除了一些和ops无关的语句。从中也可以学到Net::SNMP模块的使用，hash的解引用等~
```perl#!/usr/bin/perl -w
use strict;
use Net::SNMP;
use Getopt::Long;
use lib "/usr/local/nagios/libexec";
use utils qw(%ERRORS $TIMEOUT);
my $o_host =    undef;          # hostname
my $o_community = undef;        # community
my $o_port =    161;            # port
my $o_warn =    undef;          # warning limit
my $o_crit=     undef;          # critical limit
my $o_timeout= 10;
my $exit_code = undef;
my $o_type=undef;
my $output=undef;
my $o_perf= undef;
my %oids = (
'cpuUsage'                      => ".1.3.6.1.4.1.789.1.2.1.3.0",
'globalStatus'                  => ".1.3.6.1.4.1.789.1.2.2.4.0",
'nfsHighOps'                    => ".1.3.6.1.4.1.789.1.2.2.5.0",
'nfsLowOps'                       => ".1.3.6.1.4.1.789.1.2.2.6.0",
'netRecHighBytes'                   => ".1.3.6.1.4.1.789.1.2.2.11.0",
'netRecLowBytes'                    => ".1.3.6.1.4.1.789.1.2.2.12.0",
'netSentHighBytes'                => ".1.3.6.1.4.1.789.1.2.2.13.0",
'netSentLowBytes'                   => ".1.3.6.1.4.1.789.1.2.2.14.0",
'diskReadHighBytes'               => ".1.3.6.1.4.1.789.1.2.2.15.0",
'diskReadLowBytes'                => ".1.3.6.1.4.1.789.1.2.2.16.0",
'diskWriteHighBytes'            => ".1.3.6.1.4.1.789.1.2.2.17.0",
'diskWriteLowBytes'               => ".1.3.6.1.4.1.789.1.2.2.18.0",
);
my @oidlist=($oids{nfsHighOps},$oids{nfsLowOps});
sub check_options {
Getopt::Long::Configure ("bundling");
GetOptions(
'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
'p:i'   => \$o_port,            'port:i'        => \$o_port,
'C:s'   => \$o_community,       'community:s'   => \$o_community,
'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
#       'T:s'   => \$o_type,
);
}
########## MAIN #######
check_options();
# Connect to host
my ($session,$error);
#关键点：创建一个session连接被监控主机
($session, $error) = Net::SNMP->session(
-hostname  => $o_host,
-community => $o_community,
-port      => $o_port,
-timeout   => $o_timeout
);
if (!defined($session)) {
printf("ERROR: %s.\n", $error);
exit $ERRORS{"UNKNOWN"};
}
my $resultat=undef;
# Get rid of UTF8 translation in case of accentuated caracters (thanks to Dimo Velev).
#这里没太看懂perldoc，猜测是不开启MIB和oid的转换，这样输出结果比较简洁，不过注释掉这句运行结果毫无影响
$session->translate(Net::SNMP->TRANSLATE_NONE);
#取值的关键，get_request返回一个hash的引用。
#perldoc的原文是：“A reference to a hash is returned in blocking mode which contains the contents of the VarBindList.  In non-blocking mode, a true value is returned when no error has occurred.”
#get_request()中-callback和-delay是non-blocking模式的，而\@oids是blocking模式。
#也就是说这个脚本里返回的是一个引用。
if (Net::SNMP->VERSION &lt; 4) {
$resultat = $session->get_request(@oidlist);
} else {
$resultat = $session->get_request(-varbindlist  => \@oidlist);
}
if (!defined($resultat)) {
printf("ERROR: Description/Type table : %s.\n", $session->error);
$session->close;
exit $ERRORS{"UNKNOWN"};
}
$session->close;
my $new_nfs_ops;
my $left_shift= 2**32;
my $last_nfs_ops = 0;
my $row ;
my  $last_check_time ;
my  $update_time;
my @last_values=undef;
my $flg_created = 0;
#解引用关键点：对%$resultat的解引用$$resultat{$oids{nfsHighOps}}，其中$oids{nfsHighOps}是另一个hash——%oids中的值。
#可以采用foreach my $value ( values %$resultat ) { print "$value\n"; }的方式列出hash中的各个值。
#按照MSBs和LSBs的划分方法，通过2**32的方式合并得到64bits计数。
$new_nfs_ops= $$resultat{$oids{nfsHighOps}} *  $left_shift  +  $$resultat{$oids{nfsLowOps}};
#输出到文本文件，因为是给nagios做监控脚本，所以必须通过差值的方式计算average型数值，而不像cacti绘图时那样可以直接传递counter型数值。
if (-e "/tmp/traffic_ops_".$o_host) {
open(FILE,"&lt;"."/tmp/traffic_ops_".$o_host);
while($row = &lt;FILE>){
@last_values = split(":",$row);
$last_check_time = $last_values[0];
$last_nfs_ops = $last_values[1];
$flg_created = 1;
}
close(FILE);
} else {
$flg_created = 0;
}
$update_time = time();
unless (open(FILE,">"."/tmp/traffic_ops_".$o_host)){
print "Check mod for temporary file : /tmp/traffic_ops_".$o_host. " !\n";
exit $ERRORS{"UNKNOWN"};
}
print FILE "$update_time:$new_nfs_ops:$new_cifs_ops";
close(FILE);
if ($flg_created == 0){
print "First execution : Buffer in creation.... \n";
exit($ERRORS{"UNKNOWN"});
}
my $nfs_diff=$new_nfs_ops - $last_nfs_ops;
$nfs_diff=$new_nfs_ops if ($nfs_diff &lt; 0);
my $time_diff=$update_time - $last_check_time;
$time_diff=$update_time if ($time_diff &lt; 0);
my $nfs_ops = $nfs_diff / ( $time_diff );
printf("Nfs ops : %.2f ops/sec ", $nfs_ops);
printf("|nfsOps=".$nfs_ops."\n");
exit($ERRORS{"OK"});```
