---
layout: post
title: 用javascript操作新版本amcharts
category: web
tags:
  - amcharts
  - javascript
---

新版本的amcharts用js和html5改写。不再简单的用settings.xml而是写成js的object了。好在例子依然详细。下面贴一段从数据库里取值并绘制成多栏图式的代码：
```javascript
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <title>amStock Example</title>
        <link rel="stylesheet" href="../amcharts/style.css" type="text/css">
        <script src="../javascripts/jquery-1.7.2.min.js" type="text/javascript"></script>
        <script src="../amcharts/amstock.js" type="text/javascript"></script>
        <script type="text/javascript">
            var chart;
            var dataProvider = [];
            AmCharts.ready(function() {
                $.ajax({
                    type: "GET",
                    dataType:"jsonp",
                    url: "http://api.domain.com/database/table/find",
                    data: {"body":'{"sort":[["date",-1]], "limit":10000}'},
                    jsonp:'jsonpCallback',
                    jsonpCallback:'jsonCallbackFunction',
                    success: function(data){
                    },
                    error: function(jqXHR, textStatus, errorThrown){
                        alert(jqXHR);
                        alert(textStatus);
                        alert(errorThrown);
                    },
                });
            });
            function jsonCallbackFunction(data) {
                parseJSON(data);
                createStockChart();
            }
            function createStockChart() {
                chart = new AmCharts.AmStockChart();
                chart.pathToImages = "../amcharts/images/";
                var categoryAxesSettings = new AmCharts.CategoryAxesSettings();
                //定义显示的最小时间段，前提是X轴是Date对象
                categoryAxesSettings.minPeriod = "hh";
                chart.categoryAxesSettings = categoryAxesSettings;

                var dataSet1 = new AmCharts.DataSet();
                //注意这里的field要和json里的key一致
                dataSet1.fieldMappings = [{
                    fromField: "Total",
                    toField: "Total"
                }, {
                    fromField: "Error",
                    toField: "Error"
                }, {
                    fromField: "ErrorRate",
                    toField: "ErrorRate",
                }];
                dataSet1.dataProvider = dataProvider;
                dataSet1.categoryField = "date";
                chart.dataSets = [dataSet1];

                stockPanel1 = new AmCharts.StockPanel();
                //第一栏占全图的百分比
                stockPanel1.percentHeight = 70;
                var valueAxis1 = new AmCharts.ValueAxis();
                //Y轴数值位置，amstock中无法设定Y轴偏移量
                valueAxis1.position = "right";
                valueAxis1.axisColor = "#999999";
                stockPanel1.addValueAxis(valueAxis1);
                var graph1 = new AmCharts.StockGraph();
                graph1.valueField = "Total";
                graph1.title = "总计";
                //平滑曲线
                graph1.type = "smoothedLine";
                graph1.lineColor = "#999999";
                //曲线下方区域的透明度
                graph1.fillAlphas = 0.2;
                graph1.useDataSetColors = false;
                stockPanel1.addStockGraph(graph1);
                var stockLegend1 = new AmCharts.StockLegend();
                stockPanel1.stockLegend = stockLegend1;
                stockPanel1.drawingIconsEnabled = true;

                var valueAxis2 = new AmCharts.ValueAxis();
                valueAxis2.axisColor = "#FCD202";
                valueAxis2.gridAlpha = 0;
                valueAxis2.axisThickness = 2;
                stockPanel1.addValueAxis(valueAxis2);
                var graph2 = new AmCharts.StockGraph();
                graph2.valueAxis = valueAxis2;
                graph2.type = "smoothedLine";
                graph2.title = "错误";
                graph2.valueField = "Error";
                //绘点的形状
                graph2.bullet = "square";
                //图上超过多少点就不显示形状了
                graph2.hideBulletsCount = 30;
                graph2.lineColor = "#FCD202";
                graph2.lineThickness = 3;
                graph2.useDataSetColors = false;
                stockPanel1.addStockGraph(graph2);

                stockPanel2 = new AmCharts.StockPanel();
                stockPanel2.percentHeight = 30;
                stockPanel2.marginTop = 1;
                stockPanel2.categoryAxis.dashLength = 5;
                stockPanel2.showCategoryAxis = false;
                valueAxis5 = new AmCharts.ValueAxis();
                valueAxis5.dashLength = 5;
                valueAxis5.gridAlpha = 0;
                valueAxis5.axisThickness = 2;
                stockPanel2.addValueAxis(valueAxis5);
                var graph5 = new AmCharts.StockGraph();
                graph5.valueAxis = valueAxis5;
                graph5.valueField = "ErrorRate";
                graph5.title = "错误比率";
                //漂浮显示的文字，可用graph.valueField的[[value]]和graph.descriptionField的[[description]]
                graph5.balloonText = "[[value]]%";
                graph5.type = "column";
                graph5.cornerRadiusTop = 4;
                graph5.fillAlphas = 1;
                graph5.lineColor = "#FCD202";
                graph5.useDataSetColors = false;
                stockPanel2.addStockGraph(graph5);
                var stockLegend2 = new AmCharts.StockLegend();
                stockPanel2.stockLegend = stockLegend2;

                chart.panels = [stockPanel1, stockPanel2];

                var sbsettings = new AmCharts.ChartScrollbarSettings();
                //根据graph1显示拖动条栏
                sbsettings.graph = graph1;
                sbsettings.graphType = "line";
                sbsettings.height = 30;
                chart.chartScrollbarSettings = sbsettings;

                var cursorSettings = new AmCharts.ChartCursorSettings();
                //光标移动时跟随显示漂浮气球
                cursorSettings.valueBalloonsEnabled = true;
                chart.chartCursorSettings = cursorSettings;

                var periodSelector = new AmCharts.PeriodSelector();
                periodSelector.position = "bottom";
                periodSelector.periods = [{
                    period: "DD",
                    selected: true,
                    count: 1,
                    label: "1 day"
                }, {
                    period: "DD",
                    count: 7,
                    label: "1 week"
                }, {
                    period: "MM",
                    count: 1,
                    label: "1 month"
                }, {
                    period: "YYYY",
                    count: 1,
                    label: "1 year"
                }, {
                    period: "YTD",
                    label: "YTD"
                }, {
                    period: "MAX",
                    label: "MAX"
                }];
                chart.periodSelector = periodSelector;

                chart.write("chartdiv");
            };


            function parseDate(dateString) {
                var dateArray = dateString.split("-");
                var date = new Date(Number(dateArray[0]), Number(dateArray[1]) - 1, Number(dateArray[2]), Number(dateArray[3]));
                return date;
            }
            function parseJSON(data){
                dataProvider = data.reverse();
                //其余列原样保存，时间列必须把字符串转换成Date对象
                for( var i = 0; i < dataProvider.length; i++) {
                    dataProvider[i].date = parseDate(dataProvider[i].date);
                }
            };
        </script>
    </head>
    <body>
        <div id="chartdiv" style="width: 100%; height: 700px;"></div>
    </body>
</html>
```
