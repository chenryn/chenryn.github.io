---
layout: post
title: HTML::Template试用
date: 2011-06-01
category: perl
---

给我自己的学习计划做个开头，从html::template开始试用。
首先利用上上篇的nmap.pl脚本，提取一些数据，然后展示在页面上。
cgi脚本如下：
```perl#!/usr/bin/perl -w
use HTML::Template;
use XML::Simple;
use Net::MySQL;
#定期执行这个
#system("nmap -n -p 22,5666 10.168.168.0/23 10.168.170.0/24 -oX output.xml");
my $text = XMLin("output.xml");
#读取html模版
my $temp = HTML::Template->new(filename => '../template/html/server.tmpl');
my $localhost = '127.0.0.1';
my @array = ();
my $i = 0;
my $hash = {};
while ( $text->{host}->[$i] ) {
#因为新增了ssh端口扫描，所以xml解析和前例稍有不同
    my $ssh_state = $text->{host}->[$i]->{ports}->{port}->[0]->{state}->{state};
    my $nrpe_state = $text->{host}->[$i]->{ports}->{port}->[1]->{state}->{state};
    my $ip = ref($text->{host}->[$i]->{address}) eq 'ARRAY' ? $text->{host}->[$i]->{address}->[0]->{addr} : $text->{host}->[$i]->{address}->{addr};
    my $mac = ref($text->{host}->[$i]->{address}) eq 'ARRAY' ? $text->{host}->[$i]->{address}->[1]->{addr} : '00:1E:C9:E6:E1:7C';
    $i++;
    my $channel = &amp;mysql_query($mac);
#将ip按照频道排成列表，每个ip存有ssh和nrpe状态
    if ( exists $hash->{$channel} ) {
        push @{$hash->{$channel}}, { 'IP' => $ip, 'SSH' => $ssh_state, 'NRPE' => $nrpe_state, };
    } else {
        $hash->{$channel}->[0] = { 'IP' => $ip, 'SSH' => $ssh_state, 'NRPE' => $nrpe_state, };
    }
}
#将上面while生成的hash转成HTML::Template认可的array，不过array的单个元素可以是hash
foreach my $key( keys %{$hash} ) {
    my $onechannel = {};
    $onechannel->{"CHANNEL"} = $key;
    my $j = 0;
    foreach my $ip( @{$hash->{$key}} ) {
        $onechannel->{"IP_LOOP"}->[$j] = $ip;
        $j++;
    }
    push @array, $onechannel;
}
#将array传递给之前定义的html模版
#注意：不管是param还是@array里，所有的key必须都在tmpl里使用，冗余也会报错
$temp->param(CHANNEL_LOOP => \@array);
#输出成html格式
print "Content-Type: text/html\n\n", $temp->output;
#这段没什么说的，根据mac获取频道
sub mysql_query {
    my $mac = shift;
    my $mysql = Net::MySQL->new( hostname => $localhost,
                                 database => 'myops',
                                 user     => 'myops',
                                 password => 'myops',
                               );
    $mysql->query("select channel from myhost where mac='$mac'");
    &amp;alert("New server") unless $mysql->has_selected_record;
    my $a_record_iterator = $mysql->create_record_iterator();
    while (my $record = $a_record_iterator->each) {
        return $record->[0];
    };
}
#留着后续继续处理
sub alert {
    print @_,"\n";
}```
然后是template文件server.tmpl：
```html
<html>
<head>
<title>Server Plate</title>
</head>
<body>
<table width="100%" cellspacing="0" cellpadding="0" border="1">
<!--TMPL_LOOP循环格式，使用的是array里channel_loop的每个元素-->
<TMPL_LOOP NAME="CHANNEL_LOOP">
<tr>
<!--根据本层loop中的某个元素的channel的value开始表格的一行-->
<th><center><TMPL_VAR NAME="CHANNEL"></center></th>
<!--本层loop中另一个元素ip_loop，也是array格式，所以继续循环，每个元素使用一列-->
<TMPL_LOOP NAME="IP_LOOP">
<td valign=top><center>
//根据本层loop的ssh情况选择显示哪个图标；TMPL_IF只能判断key的真假，所以用js
<script type="text/javascript">
if ('<TMPL_VAR NAME="SSH">' == 'open') {
    document.write("<img src='../template/images/unlock_server.png'>");
} else {
    document.write("<img src='../template/images/desable_server.png'>");
}
</script>
<!--显示第二层loop里元素的几个value-->
<hr>nrpe:<TMPL_VAR NAME="NRPE"><hr>ssh :<TMPL_VAR NAME="SSH"><hr><TMPL_VAR NAME="IP">
</center></td>
<!--结束里层loop，即完成一行表格-->
</TMPL_LOOP>
</tr>
<!--结束顶层loop，即完成表格-->
</TMPL_LOOP>
</table></center><br><br><br><center>
</body>
</html>
```
用apache分别发布cgi目录和静态目录。然后访问一下；OK。
