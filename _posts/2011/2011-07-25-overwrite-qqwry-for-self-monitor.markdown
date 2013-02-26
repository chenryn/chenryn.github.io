---
layout: post
title: cdn自主监控(一):整理一个可用范围内的尽可能小的ip库
date: 2011-07-25
category: monitor
tags:
  - perl
---

为了跟第三方监控做对比和作为备用，准备自己通过页面js返回数据做个监控。首先第一步，整理一个足够自己用的ip库。
首先，考虑调用会比较频繁，打算把内容尽可能归并，到省级运营商即可；
其次，未知归并完会有多大的情况下，考虑到qqwry的地区都是中文，打算统一使用电话区号代替地区，运营商也有一位数字代替，ip采用inet-aton网络值代替；这样每条记录的字节数固定，可以方便采用seek和sysread提高读取某条记录的速度。
<hr>
前几步工作和之前整理ip库给dns用的时候一样，导出qqwry.txt，约42w条，24MB大小。
然后从网上搜一下全国电话区号，以各省省会(首府)的区号为准，存成一个quhao.txt，为了之后处理方便，只保留前两个中文，好在中国的省份里也只有内蒙古和黑龙江是三个字，留两位不至于影响阅读，txt内容如下：
{% highlight yaml %}北京 0010 
上海 0021
天津 0022
重庆 0023
安徽 0551
福建 0591
甘肃 0931
广东 0020
广西 0771
贵州 0851
海南 0898
河北 0311
河南 0371
黑龙 0451
湖北 0027
湖南 0731
吉林 0431
江苏 0025
江西 0791
辽宁 0024
内蒙 0471
宁夏 0951
青海 0971
山东 0531
山西 0351
陕西 0029
四川 0028
西藏 0891
新疆 0991
云南 0871
浙江 0571{% endhighlight %}
然后用如下perl脚本归并：
{% highlight perl %}#!/usr/bin/perl -w
my($quhao, $qqwry) = @ARGV;
$code = read_area_code($quhao);
overwrite_iplist($qqwry, $code);
sub inet_aton {
    my $ip = shift;
    my $short = sprintf "%010s", $1 * 256**3 + $2 * 256**2 + $3 * 256 + $4 if $ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
    return $short;
};

sub read_area_code {
    my $file = shift;
    my $area_code = {};
    open my $fh,'<',"$file" or die "Cannot open $file";
    while (<$fh>) {
	chomp;
        my($area,$code) = split;
	$area_code->{"$area"} = "$code";
    }
    close $fh;
    return $area_code;
};

sub overwrite_iplist {
    my($iplist, $area_code) = @_;
    my($last_begin_ip_n, $last_end_ip_n, $last_province_n, $last_isp_n);
    open my $fh,'<',"$iplist" or die "Cannoet open $iplist";
    while (<$fh>) {
	chomp;
	my($begin_ip, $end_ip, $area, $isp) = split;
	my($province_n, $isp_n);
	my $begin_ip_n = &inet_aton("$begin_ip");
	my $end_ip_n = &inet_aton("$end_ip");
        next if ($end_ip_n - $begin_ip_n) < 32;
	if ( $area =~ /学/ ) {
	    $isp_n = 4;                                          #教育网, 因为清华北大等学校记录在area里了，所以这步提前设定 
	};
	if ( $isp =~ m/电信/ ) {
	    $isp_n = 1;                                          #电信 
	} elsif ( $isp =~ m/联通/ ) {
            $isp_n = 2;                                          #联通(包括原网通) 
	} elsif ( $isp =~ m/铁通|移动/ ) {
	    $isp_n = 3;                                          #移动(包括原铁通) 
	} elsif ( $isp =~ m/学/ ) {
	    $isp_n = 4;                                          #教育网 
	} else {
	    $isp_n = 0;                                          #国外地址及其他未能识别的国内运营商 
	};

        my $province = substr($area, 0, 4);                      #中文用2字节，所以对原始记录获取前四字节即为省份名
	if ( exists $area_code->{"$province"} ) {
	    $province_n = $area_code->{"$province"};             #国内已知电话区号的省份 
	} else {
	    $province_n = '0000';                                #港澳台及外国，可能有其他未能识别的国内地址 
	};
        #下段为合并网段，之前dns时也用过
	if (!$last_province_n) {
	    ($last_begin_ip_n, $last_end_ip_n, $last_province_n, $last_isp_n) = ($begin_ip_n, $end_ip_n, $province_n, $isp_n);
	};
        if ( $last_province_n == $province_n && $last_isp_n == $isp_n ) {
	    $last_end_ip_n = $end_ip_n;
	} else {
	    printf "%010s %010s %04s %s\n", $last_begin_ip, $last_end_ip, $last_province_n, $last_isp_n;
	    ($last_begin_ip_n, $last_end_ip_n, $last_province_n, $last_isp_n) = ($begin_ip_n, $end_ip_n, $province_n, $isp_n);
	};
    };
    close $fh;
};
{% endhighlight %}
最后运行如下命令即可获得精简ip库：
{% highlight bash %}perl overwrite.pl quhao.txt qqwry.txt > newip.txt{% endhighlight %}
对比一下大小和行数：
{% highlight bash %}[root@cdn2 ~]# ll
-rw-r--r-- 1 root root   539226 Jul 25 18:18 newer.txt
-rw-r--r-- 1 root root  9058928 May 15 13:13 QQWry.dat
-rw-r--r-- 1 root root 24753935 Jul 25 15:26 qqwry.txt
-rw-r--r-- 1 root root      340 Jul 25 15:03 quhao.txt
-rw-r--r-- 1 root root     2439 Jul 25 18:17 test.pl
[root@cdn2 ~]# wc -l *
   18594 newer.txt
   34727 QQWry.dat
  428454 qqwry.txt
      30 quhao.txt
      72 test.pl{% endhighlight %}
好了，一天一天来，明天实现在这527KB的文件里快速定位ip……
