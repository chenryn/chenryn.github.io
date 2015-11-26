---
layout: post
title: cdn自主监控(四):输出xml数据
date: 2011-07-28
category: monitor
tags:
  - dancer
---

准备使用funsioncharts绘图，其采用xml数据，在绘制line图的时候，就要从mysql里读取数据，并输出成xml格式，相关配置如下：
```perl
package cachemoni;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use POSIX qw(strftime);

get '/xml' => sub {
    my $begin_time = date_format(params->{begin});
    my $end_time = date_format(params->{end});
    my $type = params->{type};
    my $color = { chinacache => '1D8BD1',
                  dnion      => 'F1683C',
                  fastweb    => '2AD62A',
                };
    my $xml_head = "<graph caption='Response Time' subcaption='from $begin_time to $end_time' hovercapbg='FFECAA' hovercapborder='F47E00' formatNumberScale='0' decimalPrecision='0' showvalues='0' numdivlines='3' numVdivlines='0' yaxisminvalue='1000' yaxismaxvalue='1800'  rotateNames='1'>\n<categories >\n";
    my $group;
    if ( $type eq 'time' ) {
        $group = 'cur_date';
    } elsif ( $type eq 'isp' ) {
        $group = 'isp';
    } elsif ( $type eq 'area' ) {
        $group = 'area';
    } else {
        return 'Error';
    };
    my $xml = cdn_select($begin_time, $end_time, $group, $color, $xml_head);
    return $xml;
};

sub get_area_code {
    my $file = shift;
    my $area_code = { '0000' => '其他' };
    open my $fh,'<',"$file" or die "Cannot open $file";
    while (<$fh>) {
	chomp;
        my($area,$code) = split;
	$area_code->{"$code"} = "$area";
    }
    close $fh;
    return $area_code;
};

sub cdn_select {
    my ($begin_time, $end_time, $group, $color, $xml) = @_;
    my $sql = "SELECT ${group},AVG(avg_time) avg FROM cdn_cron_record WHERE cdn = ? AND cur_date BETWEEN ? AND ? GROUP BY ${group} ORDER BY ${group}";
    my $sth = database->prepare($sql);
    my $i = 0;
    for my $cdn (qw{chinacache dnion fastweb}) {
        $sth->execute($cdn, $begin_time, $end_time);
        unless($i) {
            my @values;
            while ( my $ref = $sth->fetchrow_hashref ) {
                my ($avg_time, $type) = ($ref->{'avg'}, $ref->{"$group"});
                $xml .= "<category name='convert_group($group, $type)' />\n";
                push @values, $avg_time;
            };
            $xml .= "</category>\n";
            $xml .= "<dataset seriesName='$cdn' color='$color->{$cdn}'>\n";
            $xml .= "<set value='$_' />\n" for @values;
            $xml .= "</dataset>\n";
        } else {
            $xml .= "<dataset seriesName='$cdn' color='$color->{$cdn}'>\n";
            while ( my $ref = $sth->fetchrow_hashref ) {
                $xml .= "<set value='$ref->{avg}' />\n";
            };
            $xml .= "</dataset>\n";
        };
        $i++;
    };
    $xml .= '</graph>';
    return $xml;
};

sub convert_group {
    my ($group, $origin) = @_;
    if ($group eq 'cur_date') {
        return $origin;
    } elsif ($group eq 'isp') {
        my @isplist = qw(其他 电信 联通 移动 教育网);
        return $isplist[$origin];
    } elsif ($group eq 'area') {
        my $arealist = get_area_code('quhao.txt');
        my $code = sprintf("%04s",$origin);
        return $arealist->{$code};
    } else {
        return 'Error';
    };
};

sub date_format {
    my $time = shift;
    return strftime("%F %H:%M",localtime($time)) if $time =~ m/\d+/;
};```
用curl请求一下，如下：
```bash[root@naigos ~]# curl 'http://cache.monitor.china.com/xml?begin=1311739200&end=1311840000&type=time'
<graph caption='Daily Visits' subcaption='from 2011-07-27 12:00 to 2011-07-28 16:00' hovercapbg='FFECAA' hovercapborder='F47E00' formatNumberScale='0' decimalPrecision='0' showvalues='0' numdivlines='3' numVdivlines='0' yaxisminvalue='1000' yaxismaxvalue='1800'  rotateNames='1'><categories ><category name='2011-07-27 17:27:12' />
<category name='2011-07-27 17:32:12' />
<category name='2011-07-27 17:37:01' />
</category><dataset seriesName='chinacache' color='1D8BD1'><set value='300.0000' />
<set value='511.0000' />
<set value='482.0000' />
</dataset><dataset seriesName='dnion' color='F1683C'><set value='595.6667' />
<set value='432.0000' />
</dataset><dataset seriesName='fastweb' color='2AD62A'><set value='471.0000' />
<set value='431.5000' />
</dataset></graph>```
换个area参数试试：
```bash[root@naigos lib]# curl 'http://cache.monitor.china.com/xml?begin=1311739200&end=1312169668&type=area'
<graph caption='Response Time' subcaption='from 2011-07-27 12:00 to 2011-08-01 11:34' hovercapbg='FFECAA' hovercapborder='F47E00' formatNumberScale='0' decimalPrecision='0' showvalues='0' numdivlines='3' numVdivlines='0' yaxisminvalue='1000' yaxismaxvalue='1800'  rotateNames='1'>
<categories >
<category name='四川' />
<category name='江西' />
</category><dataset seriesName='chinacache' color='1D8BD1'>
<set value='511.0000' />
<set value='421.3333' />
</dataset><dataset seriesName='dnion' color='F1683C'>
<set value='482.5000' />
</dataset><dataset seriesName='fastweb' color='2AD62A'>
<set value='431.3333' />
</dataset></graph>```
呃，上面用的数据只是我自己insert的，所以出现了比较囧的条数不一致……
