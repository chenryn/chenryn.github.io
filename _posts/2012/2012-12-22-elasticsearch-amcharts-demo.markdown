---
layout: post
title: 用 Amcharts 和 ElasticSearch 做日志分析
category: logstash
tags:
  - amcharts
  - elasticsearch
  - javascript
---
之前有一篇从 ElasticSearch 官网摘下来的博客[《【翻译】用ElasticSearch和Protovis实现数据可视化》](http://chenlinux.com/2012/11/18/data-visualization-with-elasticsearch-and-protovis)。不过一来 Protovis 已经过时，二来 不管是 Protovis 的进化品 D3 还是 Highchart 什么的，我觉得在多图方面都还不如 amcharts 好用。所以在最后依然选择了老牌的 amcharts 完成。

展示品的大概背景还是 webserver 日志，嗯，这个需求应该是最有代表性的了。我们需要对webserver的性能有所了解。之前有一篇文章[《Tatsumaki框架的小demo一个》](http://chenlinux.com/2012/11/22/tatsumaki-demo/)，讲的是通过 `terms_stats` 获取固定时段内请求时间的平均值。其实这个demo是可以参照官网博客修改成纯js应用的。因为 Tatsumaki 在这里除了处理 HTTP 请求参数，什么都没干。而且这个demo目的是展示 perl 框架的处理，所以amchart方面直接就写死了各种变量。

但是还有一种需求，比如你需要的是针对某个情况超过某个百分比的分时走势统计。这时候必须多次请求 ES 来做运算，再让 js 做，不是说不行，但是多一倍数据在网络中传输，就不如在服务器端封装 API 了 —— 其实是我 js 太烂这种事情，我会告诉你们么。。。

先上两张效果图，其实这个布局我是从 facetgrapher 项目偷来的，但这个项目只适合比较不同 index 之间同时间段的数据，我建议作者修改，作者说"我自己js也是半吊子水平"。。。

![分地区错误情况统计](/images/uploads/amchart-column.png "分地区错误情况统计")

![实时分运营商错误比例统计](/images/uploads/amchart-line.png "实时分运营商错误比例统计")

__2013 年 2 月 21 日更新：利用 bullet 大小来表示 hasErr 的程度__

查询的 ES 库情况如下：

```bash
    $ curl "http://10.4.16.68:9200/demo-photo/log/_mapping?pretty=1"
    {
      "log" : {
        "properties" : {
          "brower" : {
            "type" : "string"
          },
          "date" : {
            "type" : "date",
            "format" : "dateOptionalTime"
          },
          "fromArea" : {
            "type" : "string",
            "index" : "not_analyzed"
          },
          "hasErr" : {
            "type" : "string"
          },
          "requestUrl" : {
            "type" : "string",
            "index" : "not_analyzed"
          },
          "timeCost" : {
            "type" : "long"
          },
          "userId" : {
            "type" : "string"
          },
          "xnforword" : {
            "type" : "string"
          }
        }
      }
    }
    $ curl "http://10.4.16.68:9200/demo-photo/log/_search?pretty=1&size=1" -d '{"query":{"match_all":{}}}'
    {
      "took" : 14,
      "timed_out" : false,
      "_shards" : {
        "total" : 10,
        "successful" : 10,
        "failed" : 0
      },
      "hits" : {
        "total" : 2330679,
        "max_score" : 1.0,
        "hits" : [ {
          "_index" : "demo-photo",
          "_type" : "log",
          "_id" : "iSI5xic7Qg2p9Sqk5yp-pQ",
          "_score" : 1.0, "_source" : {"hasErr":"false","date":"2012-12-06T15:04:21,983","userId":"123456789","requestUrl":"http://photo.demo.domain.com/path/to/your/app/test.jpg","brower":"chrome17.0.963.84","timeCost":750,"xnforword":["192.168.1.123","10.10.10.10"],"fromArea":"CN-UNI-OTHER"}
        } ]
      }
    }
```

然后后台是我惯用的 Dancer 框架：

```perl
    package AnalysisDemo;
    use Dancer ':syntax';
    use Dancer::Plugin::Ajax;
    use ElasticSearch;
    use POSIX qw(strftime);
    no  warnings;
    
    my $elsearch         = ElasticSearch->new( { %{ config->{plugins}->{ElasticSearch} } } );
    my $index_prefix     = 'demo-';
    my $type             = 'log';
    # 这里是对ip库的归类。数据是需要提前导入ES的，这可以是logstash发挥作用
    my $default_provider = {
        yidong    => [qw(CN-CRN CN-CMN)],
        jiaoyu    => [qw(CN-CER CN-CST)],
        dianxin   => [qw(CN-CHN)],
        liantong  => [qw(CN-UNI CN-CNC)],
        guangdian => [qw(CN-SCN)],
        haiwai => [qw(OS)],
    };
    
    get '/' => sub {
        # 通过 state API 获取 ES 集群现有的所有index列表
        # 因为是一个域名一个index，这样就有了前段页面上的域名下拉选择框
        my $indices = $elsearch->cluster_state->{routing_table}->{indices};
        template 'demo/chart',
          {
            providers => [ sort keys %$default_provider ],
            datasources =>
              [ grep { /^$index_prefix/ && s/$index_prefix// } keys %$indices ],
            inputfrom => strftime("%F\T%T", localtime(time()-864000)),
            inputto => strftime("%F\T%T", localtime()),
          };
    };
    
    # 这里把 api 拆成服务商和区域两个，没啥特殊原因，因为是分两回写的，汗
    # 其实可以看到最开始的请求参数类似，最后json的field名字都一样
    ajax '/api/provider' => sub {
        my $param = from_json(request->body);
        my $index = $index_prefix . $param->{'datasource'};
        my $from  = $param->{'from'} || 'now-10d';
        my $to    = $param->{'to'} || 'now';
        my $providers = $param->{'provider'};
        my ( $pct, $chartData );
        for my $provider ( sort @{$providers} ) {
            my $provider_pct;
            # 这里是比较麻烦的一点，因为一个区域在ip库里可能标记成多个，比如铁通和移动，现在都是移动
            for my $area ( @{ $default_provider->{$provider} } ) {
                my $res = pct_count( $index, $area, $from, $to );
                for my $time ( sort keys %{$res} ) {
                    $provider_pct->{$time}->{count} += $res->{$time}->{count};
                    $provider_pct->{$time}->{error} += $res->{$time}->{error};
                    $provider_pct->{$time}->{slow}  += $res->{$time}->{slow};
                }
            }
            # 这里因为可能没有错误，所以前面关闭了常用的 warnings 警告
            for my $time ( sort keys %{$provider_pct} ) {
                my $right_pct = 100;
                $right_pct =
                  100 -
                  $provider_pct->{$time}->{slow} / $provider_pct->{$time}->{count}
                  * 100;
                $pct->{$time}->{$provider} = sprintf "%.2f", $right_pct;
                $pct->{$time}->{"${provider}Err"} = sprintf "%.2f",
                  $provider_pct->{$time}->{error} / $provider_pct->{$time}->{count}
                  * 100;
                $pct->{$time}->{"${provider}Size"} = sprintf "%.0f",
                  $pct->{$time}->{"${provider}Err"};
            }
        };
    
        for my $time ( sort keys %$pct ) {
            my $data->{date} = $time;
            for my $provider ( @$providers ) {
                $data->{$provider} = $pct->{$time}->{$provider} || 100;
                $data->{"${provider}Err"} = $pct->{$time}->{"${provider}Err"} || 0;
                # 百分比太低，所以翻 5 倍来作为 bullet 的大小
                $data->{"${provider}Size"} =
                  $pct->{$time}->{"${provider}Size"} * 5 || 0;
            };
            push @$chartData, $data;
        };
    
        my $res = {
            type => "line",
            categoryField => "date",
            graphList => $providers,
            chartData => $chartData,
        };
    
        return to_json($res);
    };
    
    ajax '/api/area' => sub {
        my $param = from_json(request->body);
        my $index = $index_prefix . $param->{'datasource'};
        my $limit = $param->{'limit'} || 50;
        my $from  = $param->{'from'} || 'now-10d';
        my $to    = $param->{'to'} || 'now';
        # 这是后来写的，尽可能把 sub 拆分了，所以 ajax 这里就很简略
        # 当然因为不考虑多运营商的问题，本身也容易一些
        my $res = pct_terms( $index, $limit, $from, $to );
        return to_json($res);
    };
    
    sub pct_terms {
        my ( $index, $limit, $from, $to ) = @_;
        my $area_all_count = area_terms( $index, 0,    $limit, $from, $to );
        my $area_err_count = area_terms( $index, 2000, $limit, $from, $to );
        my ( $error, $chartData );
        for ( @{$area_err_count} ) {
            $error->{ $_->{term} } = $_->{count};
        }
        for ( @{$area_all_count} ) {
            push @$chartData, {
                area  => $_->{term},
                error => $error->{ $_->{term} } || 0,
                right => $_->{count} - $error->{ $_->{term} },
            };
        }
        my $res = {
            type => "column",
            categoryField => "area",
            graphList => [qw(right error)],
            chartData => $chartData,
        };
        return $res;
    }
    
    sub pct_count {
        my ( $index, $area, $from, $to ) = @_;
        my $level = $area eq 'OS' ? 3000 : 2000;
        my $all_count  = histo_count( $index, 0,      $area, $from, $to );
        my $slow_count = histo_count( $index, $level,   $area, $from, $to );
        my $err_count  = histo_count( $index, 'hasErr', $area, $from, $to );
        my $res;
        for ( @{$slow_count} ) {
            $res->{ $_->{time} }->{slow} = $_->{count};
        }
        for ( @{$err_count} ) {
            $res->{ $_->{time} }->{error} = $_->{count};
        }
        for ( @{$all_count} ) {
            $res->{ $_->{time} }->{count} = $_->{count};
        }
        return $res;
    }
    
    # 下面开始的两个才是真正发 ES 请求的地方

    sub area_terms {
        my ( $index, $level, $limit, $from, $to ) = @_;
        my $data = $elsearch->search(
            index  => $index,
            type   => $type,
            size   => 0,
            facets => {
                area => {
                    facet_filter => {
                        and => [
                            {
                                range => {
                                    date => {
                                        from => $from,
                                        to   => $to
                                    },
                                },
                            },
                            {
                                numeric_range =>
                                  { timeCost => { gte => $level, }, },
                            },
                        ],
                    },
                    # 使用最简单的 terms facets API，因为只用计数就好了
                    terms => {
                        field => "fromArea",
                        size  => $limit,
                    }
                }
            }
        );
        return $data->{facets}->{area}->{terms};
    }
    
    sub histo_count {
        my ( $index, $level, $area, $from, $to ) = @_;
        # 根据 level 参数判断使用 hasErr 还是 timeCost 列数据
        my $level_ref =
          $level eq 'hasErr'
          ? { term => { hasErr => 'true' } }
          : { numeric_range => { timeCost => { gt => $level } } };
        my $facets = {
            pct => {
                facet_filter => {
                    # 这里条件比较多，所以要用 bool API，不能用 and 了
                    bool => {
                        # must 可以提供多个条件作为 AND 数组
                        # 此外还有 must_not 作为 AND NOT 数组
                        # should 作为 OR 数组
                        must => [
                            {
                                range => {
                                    date => {
                                        from => $from,
                                        to   => $to
                                    },
                                },
                            },
                            { prefix => { fromArea => $area } },
                            $level_ref,
                        ],
                    },
                },
                # 这里是需要针对专门的时间列做汇总，所以用 date_histogram 了，具体说明之前有博客
                date_histogram => {
                    field    => "date",
                    interval => "1h",
                }
            }
        };
        my $data = $elsearch->search(
            index  => $index,
            type   => $type,
            facets => $facets,
            size   => 0,
        );
        return $data->{facets}->{pct}->{entries};
    }
```

其实把里面请求的hash拆开来一个个定义，然后根据情况组合，但是不方便察看作为 demo 的整体情况。

然后看template里怎么写。这里虽然有两个效果图，但是只有一个template哟：

```html
<link rel="stylesheet" href="[% $request.uri_base %]/amcharts/style.css" type="text/css">
<script src="[% $request.uri_base %]/amcharts/amcharts.js" type="text/javascript"></script>
<script type="text/javascript">
  var chart;

  function createAmChart(data) {
    // 清空原有图形
    $("#chartdiv").empty();
    // 如果是时间轴线图，需要把date字符转成Date对象
    if ( data.categoryField == "date" ) {
      for ( var j = 0; j < data.chartData.length; j++ ) {
        data.chartData[j].date = new Date(Number(data.chartData[j].date));
      }
    }

    chart = new AmCharts.AmSerialChart();
    // 拖动条等图片的路径
    chart.pathToImages = "/amcharts/images/";
    chart.dataProvider = data.chartData;
    chart.categoryField = data.categoryField;
    // 如果是柱状图，可以显示 3D 效果
    if ( data.type == 'column' ) {
//      chart.rotate = true;
      chart.depth3D = 20;
      chart.angle = 30;
    }
    var categoryAxis = chart.categoryAxis;
    categoryAxis.fillAlpha = 1;
    categoryAxis.fillColor = "#FAFAFA";
    categoryAxis.axisAlpha = 0;
    categoryAxis.gridPosition = "start";
    // 时间轴需要解析Date对象
    if ( data.categoryField == "date" ) {
      categoryAxis.parseDates = true;
      categoryAxis.minPeriod = "hh";
    }

    var valueAxis = new AmCharts.ValueAxis();
    valueAxis.dashLength = 5;
    valueAxis.axisAlpha = 0;
    // 指定柱状图为叠加模式，这里有多种模式可以看文档
    if ( data.type == 'column' ) {
      valueAxis.stackType = "regular";
    }
    chart.addValueAxis(valueAxis);

    // 这里有个有趣的事情，如果不把graph当数组直接循环，效果也没问题
    // 我只能猜测是 addGraph 后数据其实已经缓存到 chart 了
    var graph = [];
    var colors = ['#FF6600', '#FCD202', '#B0DE09', '#0D8ECF', '#2A0CD0', '#CD0D74', '#CC0000', '#00CC00', '#0000CC', '#DDDDDD', '#999999', '#333333', '#990000'];
    for ( var i = 0; i < data.graphList.length; i++ ) {
      graph[i] = new AmCharts.AmGraph();
      graph[i].title = data.graphList[i];
      graph[i].valueField = data.graphList[i];
      graph[i].type = data.type;
      if ( data.type == 'column' ) {
        graph[i].lineAlpha = 0;
        graph[i].fillAlphas = 1;
      } else {
        graph[i].valueField = data.graphList[i];
        graph[i].descriptionField = data.graphList[i] + "Err";
        graph[i].bulletSizeField = data.graphList[i] + "Size";
        graph[i].bullet = "round";
        // 设定为空心圆圈
        graph[i].bulletColor = "#ffffff";
        graph[i].bulletBorderAlpha = 1;
        // amchart 本来有默认颜色，不过前面因为修改了圆内的颜色，所以其他颜色无法继承默认设定了
        graph[i].bulletBorderColor =  colors[i];
        graph[i].lineColor =  colors[i];
        graph[i].lineAlpha = 1;
        graph[i].lineThickness = 1;
        graph[i].balloonText = "[[value]]% / hasErr:[[description]]%";
      }
      chart.addGraph(graph[i]);
    }

    // 加图例，这样可以在图上随时勾选察看具体某个数据，也方便某数据异常的时候影响察看其他
    var legend = new AmCharts.AmLegend();
    legend.position = "right";
    legend.horizontalGap = 10;
    legend.switchType = "v";
    chart.addLegend(legend);

    // 加拖拉轴，这样可以拖动察看细节，这个功能很赞
    var scrollbar = new AmCharts.ChartScrollbar();
    scrollbar.graph = graph[0];
    scrollbar.graphType = "line";
    scrollbar.height = 30;
    chart.addChartScrollbar(scrollbar);

    var cursor = new AmCharts.ChartCursor();
    chart.addChartCursor(cursor);

    chart.write("chartdiv");
  };

  function drawChart() {
    var provider = [];
    $("#provider :selected").each(function(){
       provider.push( $(this).val() );
    });
    var datasource = $("#datasource :selected").val();
    var apitype = $(":radio:checked").val();
    var from = $("#from").val();
    var to = $("#to").val();
    $.ajax({
      processData: false,
      url: "[% $request.uri_base %]/demo/api/" + apitype,
      data: JSON.stringify({"provider":provider, "datasource":datasource, "from":from, "to":to}),
      type: "POST",
      dataType: "json",
      success : createAmChart
    });
  };

  function showselect() {
    $("#providers").show();
  };
  function hideselect() {
    $("#providers").hide();
  };
</script>

      <div class="well">
        <div class="span8">
          <input type="text" class="input-medium" id="from" name="from" value="[% $inputfrom %]">
          <input type="text" class="input-medium" id="to" name="to" value="[% $inputto %]">
          <select class="input-medium" id="datasource">
%% for $datasources -> $datasource {
            <option value="[% $datasource %]">[% $datasource %]</option>
%% }
          </select>
        </div>
        <div class="span2">
          <label class="radio">
            <input type="radio" name="querytype" value="provider" onclick="showselect()">服务商趋势
          </label>
          <label class="radio">
            <input type="radio" name="querytype" value="area" checked onclick="hideselect()">分地区统计
          </label>
        </div>
        
        <button type="submit" class="btn btn-primary" onclick="drawChart()">查询</button>
        
        <div id ="providers" class="controls hide">
          <select class="input-medium" id="provider" multiple="mulitiple">
%% for $providers -> $provider {
            <option value="[% $provider %]" selected>[% $provider %]</option>
%% }
          </select>
        </div>
      </div><!--/well-->
      <div id="chartdiv" style="width: 100%; height: 400px;">
      </div>
```

