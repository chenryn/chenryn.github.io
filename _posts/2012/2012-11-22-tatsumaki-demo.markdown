---
layout: post
title: 用 Tatsumaki 框架写 elasticsearch 界面
category: logstash
tags:
  - perl
  - javascript
  - amcharts
---
Tatsumaki是Plack作者的一个小框架，亮点是很好的利用了psgi.streaming的接口可以async的完成响应。不过因为缺少周边支持，所以除了几个webchat的example，似乎没看到什么应用。笔者之前纯为练手，却用tatsumaki写了个sync响应的小demo，算是展示一下用tatsuamki做普通web应用的基础步骤吧：

(代码本来是作为一个ElasticSearch数据分析的平台，不过后来发现社区有人开始做纯js的内嵌进ElasticSearch的plugin了，所以撤了repo，这里贴下代码)

* 所有的psgi/plack应用都一样有自己的app.psgi文件：
{% highlight perl %}
our $VERSION = 0.01;
### app.psgi
use Tatsumaki::Error;
use Tatsumaki::Application;
use Tatsumaki::HTTPClient;
use Tatsumaki::Server;
### read config
use File::Basename;
use YAML::Syck;
my $config = LoadFile(dirname(__FILE__) . '/config.yml');
### elasticsearch init
use ElasticSearch;
#这里yml的写法借鉴Dancer::Plugin::ElasticSearch了
my $elsearch = ElasticSearch->new( $config->{'options'} );
### index init
use POSIX qw(strftime);
my $index = join '-', ( (+split( '-', $config->{'index'} ))[0], strftime( (+split( '-', $config->{'index'} ))[1], localtime ) );
my $type = $config->{'type'};
#首页类，调用了模板
package MainHandler;
use parent qw(Tatsumaki::Handler);
sub get {
    my $self = shift;
    $self->render('index.html');
};
#具体的API类
package ListHandler;
use parent qw(Tatsumaki::Handler);
sub get {
#这里自动把urlpath切分好了
    my ( $self, $group, $order, $interval ) = @_;
    return 'Not valid order' unless $order eq 'count' or $order eq 'mean';
    return 'Not valid interval' unless $interval =~ m#\d+(h|m|s)#;
    my ($key_field, $value_field);
    if ( $group eq 'url' ) {
        $key_field = 'url';
        $value_field = 'responsetime';
    } elsif ( $group eq 'ip' ) {
        $key_field = 'oh';
        $value_field = 'upstreamtime';
    } else {
        return 'Not valid group field';
    };

    # get index mapping and sort into array
    my $mapping = $elsearch->mapping(
        index => "$index",
        type  => "$type",
    );
    my @res_map;
    for my $property ( sort keys %{ $mapping->{$type}->{'properties'} } ) {
        if ($property eq '@fields' ) {
            my @fields;
            push @fields, { name => $_, type => $mapping->{$type}->{'properties'}->{$property}->{'properties'}->{$_}->{'type'} }
                for sort keys %{ $mapping->{$type}->{'properties'}->{$property}->{'properties'} };
            push @res_map, \@fields;
        } else {
            push @res_map, { name => $property, type => $mapping->{$type}->{'properties'}->{$property}->{'type'} };
        }
    }

    # get value stat group by key field
    my $data = $elsearch->search(
        index => "$index",
        type  => "$type",
        size  => 0,
        query => {
            "range" => {
                '@timestamp' => {
                    from => "now-$interval",
                    to   => "now"
                },
            },
        },
        facets => {
            "$group" => {
                "terms_stats" => {
                    "value_field" => "$value_field",
                    "key_field"   => "$key_field",
                    "order"       => "$order",
                    "size"        => 20,
                }
            },
        }
    );
    my @res_tbl;
    for ( @{$data->{facets}->{"$group"}->{terms}} ) {
        my $key = $_->{term};
        my $mean = sprintf "%.03f", $_->{mean};
        my $code_count = code_count($key_field, $key, $interval);
        push @res_tbl, {
            key   => $key,
            min   => $_->{min},
            max   => $_->{max},
            mean  => $mean,
            code  => $code_count,
            count => $_->{count},
        };
    };

# render可以接收参数，并且默认把$self带进去，具体key是handler
    $self->render('index.html', { table => \@res_tbl, mapping => \@res_map });
};

sub code_count {
    my ($key_field, $key, $interval) = @_;
    my $result;
    my $data = $elsearch->search(
        index => "$index",
        type  => "$type",
        size  => 0,
        query => {
            range => {
                '@timestamp' => {
                    from => "now-$interval",
                    to   => "now"
                },
            },
        },
        facets => {
            "code" => {
                facet_filter => {
                    term => {
                        $key_field => "$key"
                    }
                },
                terms => {
                    field => "status",
                }
            }
        }
    );
    for ( @{$data->{facets}->{code}->{terms}} ) {
        $result->{$_->{term}} = $_->{count};
    };
    return $result;
};
#画图数据API类，因为响应的是Ajax请求，所以这里开启了async，不过其实没意义了。因为这个ElasticSearch代码不是async格式的。应该改造用ElasticSearch::Transport::AEHTTP才能做到全程async。
package ChartHandler;
use parent qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);
use JSON;
sub post {
    my $self = shift;
    my $api = $self->request->param('api') || 'term';
    my $key = $self->request->param('key') || 'oh';
    my $value = $self->request->param('value');
    my $status = $self->request->param('status') || '200';

    my $field =  $key eq 'oh' ? 'upstreamtime' : 'responsetime';
    my $data = $elsearch->search(
        index => "$index",
        type  => "$type",
        size  => 0,
        query => {
            match_all => { }
        },
        facets => {
            "chart" => {
                facet_filter => {
                    and => [
                        {
                            term => {
                                status => $status,
                            },
                        },
                        {
                            $api => {
                                $key => $value,
                            },
                        },
                    ]
                },
                date_histogram => {
                    value_field => $field,
                    key_field => '@timestamp',
                    interval => "1m"
                }
            },
        },
    );
    my @result;
    for ( @{$data->{'facets'}->{'chart'}->{'entries'}} ) {
        push @result, {
           time => $_->{'time'},
           count => $_->{'count'},
           mean => sprintf "%.3f", $_->{'mean'} * 1000,
        };
    };
    header('Content-Type' => 'application/json');
    to_json(\@result);
};
#主函数
package main;
use File::Basename;
#通过Tatsumaki::Application绑定urlpath到不同的类上。注意下面listhandler那里用的正则捕获。对，上面类里传参就是这么来的。注意最多不超过$9。
my $app = Tatsumaki::Application->new([
    '/' => 'MainHandler',
    '/api/chartdata' => 'ChartHandler',
    '/api/(\w+)/(\w+)/(\w+)' => 'ListHandler',
]);
#指定template和static的路径。类似Dancer里的views和public
$app->template_path(dirname(__FILE__) . '/templates');
$app->static_path(dirname(__FILE__) . '/static');
#psgi app组建完成
return $app->psgi_app;
true;
{% endhighlight %}
static里都是bootstrap的东西就不贴了。然后说说template。目前Tatsumaki只支持Text::MicroTemplate::File一种template，当然自己在handler里调用其他的template然后返回字符串也行。不过其实Text::MicroTemplate也蛮强大的。下面上例子：
{% highlight html %}
%# 这就是Text::MicroTemplate强大的地方了，行首加个百分号就可以直接使用perl而不像TT那样尽量搞自己的语法
%# 配合render传来的handler(前面说了是类$self)，整个环境全可以任意调用。
% my $mapping = $_[0]->{'mapping'};
% my $table = $_[0]->{'table'};
%# 比如这里其实就是通过handler调用request了。
% my $group = $_[0]->{handler}->args->[0];
% my @codes = qw(200 206 302 304 400 403 404 499 502 503 504);
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-type" content="text/html; charset=utf-8" />
<title>Bubble -- a perl webui for logstash & elasticsearch</title>
<link rel="stylesheet" href="/static/bootstrap/css/bootstrap.css" >
<link rel="stylesheet" href="/static/fontawesome/css/font-awesome.css" >
<link rel="stylesheet" href="/static/css/style.css" >
<link rel="stylesheet" href="/static/amcharts/style.css" type="text/css">
</head>
<body>
<div class="container">
<div class="container-fluid">
  <div class="row-fluid">
    <div class="span3">
      <div class="well sidebar-nav">
        <ul class="nav nav-list">
          <li class="nav-header">查询</li>
% for my $property ( @{ $mapping } ) {
%     if ( ref( $property ) eq 'ARRAY' ) {
          <li>@fields</li>
%          for ( @{$property} ) {
          <li>  - <%= $_->{'name'} %> <%= $_->{'type'} %></li>
%          }
%     } elsif ( $property->{'type'} ) {
          <li><%= $property->{'name'} %> <%= $property->{'type'} %></li>
%     }
% }
        </ul>
      </div>
    </div>
    <div class="span9">
      <div id="search">
        <div class="control-group">
          <div class="controls docs-input-sizes">
            <select class="input-small inline" id="esapi" name="api">
              <option>匹配方式</option>
              <option>prefix</option>
              <option>term</option>
              <option>text</option>
            </select>
            <select class="input-small inline" id="eskey" name="key">
              <option>查询列</option>
              <option>oh</option>
              <option>url</option>
            </select>
            <input type="text" class="input-big inline" id="esvalue" name="value" placeholder="查询文本" />
            <input type="text" class="input-small inline" id="esstatus" name="status" placeholder="指定状态" />
            <button class="btn btn-primary" onclick="genchart()">查看</button>
          </div>
        </div>
      </div>
      <div id="chartdiv" style="display:none; width: 100%; height: 500px;"></div>
      <div id="estable">
% if ( $table ) {
        <table class="table table-striped table-bordered table-condensed">
          <thead>
            <tr>
              <th><%= $group %></th>
              <th>平均响应时间</th>
              <th>最大响应时间</th>
              <th>下载数</th>
%     for ( @codes ) {
              <th><%= $_ %></th>
%     }
            </tr>
          </thead>
          <tbody>
%     for my $list ( @{ $table } ) {
            <tr>
              <td><%= $list->{'key'} %></td>
              <td><%= $list->{'mean'} %></td>
              <td><%= $list->{'max'} %></td>
              <td><%= $list->{'count'} %></td>
%         for ( @codes ) {
%             if ( $list->{'code'}->{$_} ) {
              <td><%= $list->{'code'}->{$_} %></td>
%             } else {
              <td></td>
%             }
%         }
            </tr>
%     }
          </tbody>
        </table>
% }
      </div>
    </div>
  </div>
</div>
</div>
<script src="/static/javascripts/jquery-1.7.2.min.js"></script>
<script src="/static/bootstrap/js/bootstrap.min.js"></script>
<script src="/static/amcharts/amstock.js" type="text/javascript"></script>
<script type="text/javascript">
  var chart;
  var chartProvider = [];
  function createStockChart() {
    chart = new AmCharts.AmStockChart();
    chart.pathToImages = "/static/amcharts/images/";
    var categoryAxesSettings = new AmCharts.CategoryAxesSettings();
    categoryAxesSettings.parseDates = true;
    categoryAxesSettings.minPeriod = "mm";
    chart.categoryAxesSettings = categoryAxesSettings;
    var dataSet = new AmCharts.DataSet();
    dataSet.fieldMappings = [{
      fromField : "count",
      toField : "count",
    }, {
      fromField : "mean",
      toField : "mean",
    }];
    dataSet.dataProvider = chartProvider;
    dataSet.categoryField = "date";
    chart.dataSets = [dataSet];

    var stockPanel1 = new AmCharts.StockPanel();
    stockPanel1.percentHeight = 70;

    var valueAxis1 = new AmCharts.ValueAxis();
    valueAxis1.position = "left";
    valueAxis1.axisColor = "#999999";
    stockPanel1.addValueAxis(valueAxis1);

    var graph1 = new AmCharts.StockGraph();
    graph1.valueField = "mean";
    graph1.title = "mean(ms)";
    graph1.type = "smoothedLine";
    graph1.lineColor = "#999999";
    graph1.fillAlphas = 0.2;
    graph1.useDataSetColors = false;
    stockPanel1.addStockGraph(graph1);

    var stockLegend1 = new AmCharts.StockLegend();
    stockPanel1.stockLegend = stockLegend1;
    stockPanel1.drawingIconsEnabled = true;

    var stockPanel2 = new AmCharts.StockPanel();
    stockPanel2.percentHeight = 30;
    stockPanel2.marginTop = 1;
    stockPanel2.categoryAxis.dashLength = 5;
    stockPanel2.showCategoryAxis = false;

    valueAxis2 = new AmCharts.ValueAxis();
    valueAxis2.dashLength = 5;
    valueAxis2.gridAlpha = 0;
    valueAxis2.axisThickness = 2;
    stockPanel2.addValueAxis(valueAxis2);

    var graph2 = new AmCharts.StockGraph();
    graph2.valueAxis = valueAxis2;
    graph2.valueField = "count";
    graph2.title = "count";
    graph2.balloonText = "[[value]]%";
    graph2.type = "column";
    graph2.cornerRadiusTop = 4;
    graph2.fillAlphas = 1;
    graph2.lineColor = "#FCD202";
    graph2.useDataSetColors = false;
    stockPanel2.addStockGraph(graph2);

    var stockLegend2 = new AmCharts.StockLegend();
    stockPanel2.stockLegend = stockLegend2;

    chart.panels = [stockPanel1, stockPanel2];

    var sbsettings = new AmCharts.ChartScrollbarSettings();
    sbsettings.graph = graph2;
    sbsettings.graphType = "line";
    sbsettings.height = 30;
    chart.chartScrollbarSettings = sbsettings;

    var cursorSettings = new AmCharts.ChartCursorSettings();
    cursorSettings.valueBalloonsEnabled = true;
    chart.chartCursorSettings = cursorSettings;

    $("#chartdiv").show();
    chart.write("chartdiv");

  };

  function genchart() {
    $.getJSON('/api/chartdata', {
      api : $("#esapi").val(),
      key : $("#eskey").val(),
      status : $("#esstatus").val(),
      value : $("#esvalue").val(),
    }, function(data) {
      for ( var i = 0; i < data.length; i++ ) {
        var date = new Date(data[i].time);
        chartProvider.push({
          date: date,
          count: data[i].count,
          mean: data[i].mean,
        });
      }
      createStockChart();
    });
  };
</script>
</body>
</html>
{% endhighlight %}

效果如下：

![查询表格并提交最多次的url绘图](/images/uploads/tatsumaki.png "查询表格并提交最多次的url绘图")

-----

__2012 年 12 月 30 日附注：__

更好的纯 js 版本已经作为独立的 elasticsearch-plugin 项目发布在 github 上。地址：<https://github.com/chenryn/elasticsearch-logstash-faceter> 。欢迎大家试用!!
