---
layout: post
title: Chart::OFC试用
date: 2011-12-19
category: perl
---

这几天ppt看的比较多，一样一样来玩。今天先说OFC，之前有试过amcharts和fusioncharts。amcharts最全最漂亮（尤其是有scroll和map），可惜图上都自动标上了amcharts.com的字样；fusioncharts的free版本，也蛮好用的，虽然scroll怪怪的居然靠的是点击控制。比较相同的一点就是，这两都只提供了php、python等的模块，如果是perl写的网页，那只能通过提供xml/json数据给js控制的办法。稍微一点点遗憾……
这次在cpan上终于看到一个chart控制的模块，叫Chart::OFC。这个OFC的项目地址如下：
<a href="http://teethgrinder.co.uk/open-flash-chart/" target="_blank">http://teethgrinder.co.uk/open-flash-chart/</a>
其实用法上没什么特殊，无非是省略一点点xml代码，通过OO的方式自动生成而已。让我觉得蛮好玩的是官网上作者的声明。因为他曾经在维护公司一个付费的flash chart项目时，给甲方发信要求修改bug，等了一个月没反应。于是自己现学as语言开始自己搞= =！然后念念不忘的提示说：要重视客户的反馈。。。。。。哈哈
这个项目目前用as3改写，所以新版本叫OFC2了，不过作者自己也说不太稳定，建议继续用OFC1.9.7，所以先不说Chart::OFC2，继续用Chart::OFC好了：

{% highlight perl %}

get '/ofc_data' => sub {
    use Chart::OFC;
    my $line_array = [1 .. 20];
    my $bars_array; @$bars_array = map {$_ - 2.5} @$line_array;
    my $leng = $#$line_array + 1;
    my $bars = Chart::OFC::Dataset::Bar->new( values => $bars_array );
    my $line = Chart::OFC::Dataset::Line->new( values => $line_array );

    my $x_axis = Chart::OFC::XAxis->new( axis_label => 'X Axis', label_steps => 2, tick_steps => 2, labels => $line_array );
    my $y_axis = Chart::OFC::YAxis->new( axis_label => 'Y Axis', max => $leng, label_steps => 2 );

    my $grid = Chart::OFC::Grid->new( title    => 'My Grid Chart',
                                      datasets => [ $bars, $line ],
                                      x_axis   => $x_axis,
                                      y_axis   => $y_axis,
                                    );
    return $grid->as_ofc_data();
};

get '/ofc_test' => sub {
    template 'ofc';
};

{% endhighlight %}

然后ofc.tt是这样：

{% highlight html %}

<html><head>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
<body>
<script type="text/javascript" src="/ofc/js/swfobject.js"></script>
<div id="my_chart"></div>
<script type="text/javascript">
var so = new SWFObject("/ofc/actionscript/open-flash-chart.swf", "ofc", "500", "200", "9", "#FFFFFF");
so.addVariable("data", "/ofc_data");
so.addParam("allowScriptAccess", "always" );//"sameDomain");
so.write("my_chart");
</script>
<div>boo</div>
</body>
</html>

{% endhighlight %}

运行即可。
这里chart主要分两种，pie和grid。
bar和line都是grid的。Chart::OFC的pod里举例是pie的，我这里写的举例是grid的，来自Chart::OFC::Grid的说明；
在DataSet中可以看到，area、candle和scatter都是从Line.pm模块extends出来的（嗯，这个模块是用Moose构建滴），所以具体生成的时候都是用grid。
<img src="/images/uploads/ofc.png" alt="" title="ofc" width="600" height="240" class="alignnone size-full wp-image-2824" />
<hr />
另外，CPAN上还有一个模块是给XML/SWF Chart生成数据的，不过那个东东也是要buy滴……
再另，有木有仪表盘的charts可用呢……
