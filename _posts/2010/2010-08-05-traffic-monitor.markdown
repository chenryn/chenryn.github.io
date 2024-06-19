---
layout: post
theme:
  name: twitter
title: 流量监控
date: 2010-08-05
category: monitor
tags:
  - perl
  - nagios
---

流量监控，一般看cacti上的绘图。近日打算设置报警，懒得给cacti加模块，自己写个脚本吧，于是开始研究这个流量监控的方式。
先是在网上看到一个nagios的check_traffic.sh脚本，核心就是用snmpwalk取网卡总流量，写在/tmp/某个文件下，下次nrpe启动check时，再去新的总流量，减去文件中读取出来的值，除以启动间隔时间，就是平均流量值。
用snmpwalk -v 2c -c public localhost IF-MIB::ifInOctets取出值来一看，发现和ifconifg出来的RX数值是一样的！
然后有张宴的net.sh脚本，从/proc/net/dev中取值，然后存进变量后，sleep一定时间，再取一次，同样相减再做除法，得出平均流量值。
再cat /proc/net/dev和ifconfig的一比较，数值也是一样的，把两个脚本设定相同间隔，同时运行，显示的结果都是一样的！
那从本机监控的角度来说，那当然是从proc中取值计算容易了。毕竟给一大把机器装snmpwalk很费的……
（因为近期cacti上的图时不时有某些机器突发满载流量尖峰，持续时间又很短，所以靠cacti或者nagios本身这种间隔性轮询扫描很可能就错过去了）
最终想法是，在机器上后台长期运行监控脚本，碰到流量突发，发送到监控服务器，监控服务器上开启sniffer或者wireshark抓包，同时发邮件报警。
目前初步完成监控客户端脚本如下：

```perl
#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket;
use Getopt::Long;
use POSIX qw(strftime);
#Init
my %traf;
my ($warning,$interval,$usage,$silent);
my ($eth0_in,$eth0_out,$eth1_in,$eth1_out);
my $alarm = 0;
$warning = "1000,2000,10000,80000";
$interval = 10;
#get options
Getopt::Long::Configure('bundling');
GetOptions(
    "h" => $usage, "v" => $usage,
    "s" = $silent,
    "w=s" => $warning,
    "H=s" => $peer,
    "t=f" => $interval,
);
if ($usage) {
    usage;
}
if ($warning) {
    usage unless $warning =~ /d+,d+,d+,d+/;
}
my ($eth0_in_warn,$eth0_out_warn,$eth1_in_warn,$eth1_out_warn) = split(/,/,$warning);
#fork
defined(my $pid=fork) or die "Cant fork:$!";
unless($pid){
}else{
    exit 0;
}
#main
while (1) {
#这点很奇怪，本打算把main里头的东西直接写在while里的，运行却一直没输出；只要定义成sub，立马就好用……
    main;
}
#functions
sub main {
    ($eth0_in,$eth0_out,$eth1_in,$eth1_out) = count;
    #每5分钟保存到tmp文件，供nrpe读取数据，给nagios画图用
    my $nrpetime = strftime("%M%S",localtime);
    if ($nrpetime =~ /d(5|0)0d/) {
        write_for_nrpe;
    }
    alarm unless($silent);
}
sub count {
    data;
    $traf{"eth0In_old"} = $traf{eth0In};
    $traf{"eth1In_old"} = $traf{eth1In};
    $traf{"eth0Out_old"} = $traf{eth0Out};
    $traf{"eth1Out_old"} = $traf{eth1Out};
    sleep $interval;
    data;
    my $eth0_in_flow = sprintf "%.2f",($traf{eth0In}-$traf{"eth0In_old"})/$interval*8/1024;
    my $eth1_in_flow = sprintf "%.2f",($traf{eth1In}-$traf{"eth1In_old"})/$interval*8/1024;
    my $eth0_out_flow = sprintf "%.2f",($traf{eth0Out}-$traf{"eth0Out_old"})/$interval*8/1024;
    my $eth1_out_flow = sprintf "%.2f",($traf{eth1Out}-$traf{"eth1Out_old"})/$interval*8/1024;
    return $eth0_in_flow,$eth0_out_flow,$eth1_in_flow,$eth1_out_flow;
}
sub data {
    open DEV,"&lt;/proc/net/dev" || die "Cannot open procfs!";
    while (defined(my $ifdata=&lt;DEV>)){
        next if $ifdata !~ /eth/;
        my @data = split (/:|s+/,$ifdata);
        $traf{"$data[1]In"} = $data[2];
        $traf{"$data[1]Out"} = $data[10];
    }
    close DEV;
}
sub write_for_nrpe {
    open FH,">/tmp/if_flow.txt" || die $!;
    print FH "$eth0_in|$eth0_out|$eth1_in|$eth1_out";
    close FH;
}
sub alarm {
    #考虑到默认10s取值一次，突发流量如果持续100s，就会向socket发送10次，所以进行判定，只在突发开始和突发结束时发送warn和ok。写的很初级……
    my $alarm_int = 0;
    $alarm_int = 1 if ($eth0_in-$eth0_in_warn>0);
    $alarm_int = 1 if ($eth0_out-$eth0_out_warn>0);
    $alarm_int = 2 if ($eth1_in-$eth1_in_warn>0);
    $alarm_int = 2 if ($eth1_out-$eth1_out_warn>0);
    next if $alarm_int == $alarm;
    call_sniffer("eth0:WARN") if ($alarm_int-$alarm==1);
    call_sniffer("eth1:WARN") if ($alarm_int-$alarm==2);
    call_sniffer("eth0:OK") if ($alarm_int-$alarm==-1);
    call_sniffer("eth1:OK") if ($alarm_int-$alarm==-2);
    $alarm = $alarm_int;
}
sub call_sniffer {
    my $message = shift;
    my $socket = IO::Socket::INET->new(PeerAddr => $peer,
                                       PeerPort => 12345,
                                       Proto    => 'tcp')
                 or die $@;
    print $socket "${message}n";
    $socket->shutdown(1);
    my $answer = <$socket>;
    if ($answer) {
        print $answer;
    }
    $socket->close or die $!;
}
sub usage {
    print "Version: check_eth_flow.pl v0.1n";
    print "Usage: check_eth_flow.pl -w 1000,2000,10000,80000 -t 10n";
    print "tt-w Warning Value: eth0_in,eth0_out,eth1_in,eth1_out;n";
    print "tt-t Interval Time;n";
    print "tt-s Silent write for nagios;n"
    print "tt-H Host address of peer;n";
    print "tt-h Print this usage.n";
    exit 0;
}
```

nrpe的check_if_flow.sh就比较简单了，如下：

```bash
#!/bin/bash
while getopts "w:c:h" OPT;do
    case $OPT in
    w)
        WARNING=${OPTARG}
        eth0_in_warn=`echo $WARNING|awk -F, '{print $1}'`
        eth0_out_warn=`echo $WARNING|awk -F, '{print $2}'`
        eth1_in_warn=`echo $WARNING|awk -F, '{print $3}'`
        eth1_out_warn=`echo $WARNING|awk -F, '{print $4}'`
        ;;
    c)
        CRITICAL=${OPTARG}
        eth0_in_critical=`echo $CRITICAL|awk -F, '{print $1}'`
        eth0_out_critical=`echo $CRITICAL|awk -F, '{print $2}'`
        eth1_in_critical=`echo $CRITICAL|awk -F, '{print $3}'`
        eth1_out_critical=`echo $CRITICAL|awk -F, '{print $4}'`
        ;;
    *)
        echo "Usage: $0 -w 500,500,1000,1000 -c 2000,2000,10000,10000"
        exit 0
        ;;
    esac
done
eth0_in=`cat /tmp/if_flow.txt|awk -F| '{print $1}'`
eth0_out=`cat /tmp/if_flow.txt|awk -F| '{print $2}'`
eth1_in=`cat /tmp/if_flow.txt|awk -F| '{print $3}'`
eth1_out=`cat /tmp/if_flow.txt|awk -F| '{print $4}'`
eth0_in_diff=`echo "$eth0_in &lt; $eth0_in_warn"|bc`
eth0_out_diff=`echo "$eth0_out &lt; $eth0_out_warn"|bc`
eth1_in_diff=`echo "$eth1_in &lt; $eth1_in_warn"|bc`
eth1_out_diff=`echo "$eth1_out &lt; $eth1_out_warn"|bc`
eth0_in_diff_2=`echo "$eth0_in > $eth0_in_critical"|bc`
eth0_out_diff_2=`echo "$eth0_out > $eth0_out_critical"|bc`
eth1_in_diff_2=`echo "$eth1_in > $eth1_in_critical"|bc`
eth1_out_diff_2=`echo "$eth1_out > $eth1_out_critical"|bc`
if [[ $eth0_in_diff_2 -eq 1 ]] || [[ $eth0_out_diff_2 -eq 1 ]] || [[ $eth1_in_diff_2 -eq 1 ]] || [[ $eth1_out_diff_2 -eq 1 ]];then
    echo "CRITICAL!The flow are $eth0_in,$eth0_out,$eth1_in,$eth1_out Kb|eth0_in=${eth0_in}Kbps;${eth0_in_warn};${eth0_in_critical};0;0 eth0_out=${eth0_out}Kbps;${eth0_out_warn};${eth0_out_critical};0;0 eth1_in=${eth1_in}Kbps;${eth1_in_warn};${eth1_in_critical};0;0 eth1_out=${eth1_out}Kbps;${eth1_out_warn};${eth1_out_critical};0;0"
    exit 2
elif [[ $eth0_in_diff -eq 1 ]]  [[ $eth0_out_diff -eq 1 ]]  [[ $eth1_in_diff -eq 1 ]]  [[ $eth1_out_diff -eq 1 ]];then
    echo "OK!The flow are $eth0_in,$eth0_out,$eth1_in,$eth1_out Kb|eth0_in=${eth0_in}Kbps;${eth0_in_warn};${eth0_in_critical};0;0 eth0_out=${eth0_out}Kbps;${eth0_out_warn};${eth0_out_critical};0;0 eth1_in=${eth1_in}Kbps;${eth1_in_warn};${eth1_in_critical};0;0 eth1_out=${eth1_out}Kbps;${eth1_out_warn};${eth1_out_critical};0;0"
    exit 0
else
    echo "WARNING!The flow are $eth0_in,$eth0_out,$eth1_in,$eth1_out Kb|eth0_in=${eth0_in}Kbps;${eth0_in_warn};${eth0_in_critical};0;0 eth0_out=${eth0_out}Kbps;${eth0_out_warn};${eth0_out_critical};0;0 eth1_in=${eth1_in}Kbps;${eth1_in_warn};${eth1_in_critical};0;0 eth1_out=${eth1_out}Kbps;${eth1_out_warn};${eth1_out_critical};0;0"
    exit 1
fi
```
