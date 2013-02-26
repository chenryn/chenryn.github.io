---
layout: post
title: cdn自主监控(六):数据展示页面
date: 2011-08-02
category: monitor
tags:
  - html
---

接下来进入我不擅长的页面部分了。规划页面分为side和main，side中提供时间选择框/类型下拉选择框和提交按钮；main中展示最后形成的chart。
时间选择框是用js和css完成的，这个网上有很多，不过要同时支持多浏览器和分钟级别的选项的，目前就发现一个好用的。下载地址如下：<http://chenlinux.com/images/uploads/Calendar.zip>
然后创建cachemoni/public/cdn.html如下：
{% highlight html %}
<HTML>
<HEAD>
<META NAME="ROBOTS" CONTENT="NOINDEX, NOFOLLOW">
<TITLE>CDN Monitor</TITLE>
</HEAD>
<FRAMESET BORDER="0" FRAMEBORDER="0" FRAMESPACING="0" COLS="270,*">
<FRAME SRC="side.html" NAME="side" TARGET="main">
<FRAME SRC="main.html" NAME="main">
</FRAMESET>
</HTML>{% endhighlight %}
cachemoni/public/side.html如下：
{% highlight html %}
<link type="text/css" rel="stylesheet" href="css/calendar.css" />
<script language="javascript" src="javascripts/calendar.js"></script>
select_time<HR>
<form action="/cdncharts" method="get" target="main">
<LI>begin</LI>
<input name="timefrom" type="text" id="timefrom" style="width:100%;" onclick="displayCalendar(this, 'yyyy-mm-dd hh:ii', this, true, '');"/>
<LI>end</LI>
<input name="timeto" type="text" id="timeto" style="width:100%;" onclick="displayCalendar(this, 'yyyy-mm-dd hh:ii', this, true, '');"/><HR>
<select name="chartstype" id="chartstype">
<option value="area">area</option>
<option value="isp">isp</option>
<option value="time" selected>time</option>
</select>
<input type="submit" value="submit" id="submit">
</form>{% endhighlight %}
cachemoni/views/charts.tt如下：
{% highlight html %}
<html>
<head>
<title>FusionCharts Free Documentation</title>
<link rel="stylesheet" href="css/chartstyle.css" type="text/css" />
<script language="JavaScript" src="javascripts/FusionCharts.js"></script>
</head>

<body>
<table width="98%" border="0" cellspacing="0" cellpadding="3" align="center">
  <tr> 
    <td valign="top" class="text" align="center"> <div id="chartdiv" align="center"> 
        FusionCharts. 
      <script type="text/javascript">
		   var chart = new FusionCharts("[% IF line %]chartswf/FCF_MSLine.swf[% ELSE %]chartswf/FCF_MSBar2D.swf[% END %]", "ChartId", "400", "350");
		   chart.setDataURL(escape("[% url %]"));
		   chart.render("chartdiv");
		</script> </td>
  </tr>
</table>
</body>
</html>{% endhighlight %}
cachemoni/lib/cachemoni.pm中相关函数如下：
{% highlight perl %}
use Time::Local;
get '/cdncharts' => sub {
    my $type = params->{chartstype};
    my $begin = unix_time_format(params->{timefrom});
    my $end = unix_time_format(params->{timeto});
    my $req_url = "/xml?begin=${begin}&end=${end}&type=${type}";
    my $line = 1 if $type eq 'time';
    template 'charts', { line => $line, url => "$req_url", };
};

sub unix_time_format {
    my $time = shift;
    if ( $time =~ m/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})/ ) {
        return timelocal('00',$5,$4,$3,$2-1,$1-1900);
    };
};{% endhighlight %}
这里比较怪的是，如果setDataURL里传的arg是直接2011-08-01 11:00的格式，fusionchart.js不会发起请求，只有1311111111才行，所以只能在用Time::Local模块转换时间了。
最终访问结果如下：
<img src="/images/uploads/calendar.png" alt="" title="QQ截图20110802191306" width="697" height="370" class="alignnone size-full wp-image-2555" />

