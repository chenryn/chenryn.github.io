---
layout: post
title: 【翻译】用ElasticSearch和Protovis实现数据可视化
category: logstash
tags:
  - elasticsearch
  - javascript
---
搜索引擎最重要的目的，嗯，不出意料就是`搜索`。你传给它一个请求，然后它依照相关性返回你一串匹配的结果。我们可以根据自己的内容创造各种请求结构，试验各种不同的分析器，搜索引擎都会努力尝试提供最好的结果。

不过，一个现代的全文搜索引擎可以做的比这个更多。因为它的核心是基于一个为了高效查询匹配文档而高度优化过的数据结构——[倒排索引](http://en.wikipedia.org/wiki/Index_\(search_engine\)#Inverted_indices)。它也可以为我们的数据完成复杂的`聚合`运算，在这里我们叫它facets。(不好翻译，后文对这个单词都保留英文)

facets通常的目的是提供给用户某个方面的导航或者搜索。 当你在网上商店搜索“相机”，你可以选择不同的制造商，价格范围或者特定功能来定制条件，这应该就是点一下链接的事情，而不是通过修改一长串查询语法。

一个[LinkedIn的导航](http://blog.linkedin.com/2009/12/14/linkedin-faceted-search/)范例如下图所示：

![图片1](http://www.elasticsearch.cn/blog/images/dashboards/linkedin-faceted-search.png)

Facet搜索为数不多的几个可以把强大的请求能力开放给最终用户的办法之一，详见Moritz Stefaner的试验[“Elastic Lists”](http://well-formed-data.net/archives/54/elastic-lists)，或许你会有更多灵感。

但是，除了链接和复选框，其实我们还能做的更多。比如利用这些数据画图，而这就是我们在这篇文章中要讲的。

# 实时仪表板

在几乎所有的分析、监控和数据挖掘服务中，或早或晚的你都会碰到这样的需求：“我们要一个仪表板！”。因为大家都爱仪表板，可能因为真的有用，可能单纯因为它漂亮~这时候，我们不用写任何[OLAP](http://en.wikipedia.org/wiki/Online_analytical_processing)实现，用facets就可以完成一个很漂亮很给力的分析引擎。

下面的截图就是从一个[社交媒体监控应用](http://ataxosocialinsider.cz/)上获取的。这个应用不单用ES来搜索和挖掘数据，还通过交互式仪表板提供数据聚合功能。

![图片2](http://www.elasticsearch.cn/blog/images/dashboards/dashboard.png)

当用户深入数据，添加一个关键字，使用一个自定义查询，所有的图都会实时更新，这就是facet聚合的工作方式。仪表板上不是数据定期计算好的的静态快照，而是一个用于数据探索的真正的交互式工具。

在本文中，我们将会学习到怎样从ES中获取数据，然后怎么创建这些图表。

# 关系聚合(terms facet)的饼图

第一个图，我们用ES中比较简单的[terms](http://elasticsearch.org/guide/reference/api/search/facets/terms-facet.html)facet来做。这个facet会返回一个字段中最常见的词汇和它的计数值。

首先我们先插入一些数据。

{% highlight bash %}
curl -X DELETE "http://localhost:9200/dashboard"
curl -X POST "http://localhost:9200/dashboard/article" -d '
             { "title" : "One",
               "tags"  : ["ruby", "java", "search"]}
'
curl -X POST "http://localhost:9200/dashboard/article" -d '
             { "title" : "Two",
               "tags"  : ["java", "search"] }
'
curl -X POST "http://localhost:9200/dashboard/article" -d '
             { "title" : "Three",
               "tags"  : ["erlang", "search"] }
'
curl -X POST "http://localhost:9200/dashboard/article" -d '
             { "title" : "Four",
               "tags"  : ["search"] }
'
curl -X POST "http://localhost:9200/dashboard/_refresh"
{% endhighlight %}

你们都看到了，我们存储了一些文章的标签，每个文章可以多个标签，数据以JSON格式发送，这也是ES的文档格式。

现在，要知道文档的十大标签，我们只需要简单的请求：

{% highlight bash %}
curl -X POST "http://localhost:9200/dashboard/_search?pretty=true" -d '
{
    "query" : { "match_all" : {} },

    "facets" : {
        "tags" : { "terms" : {"field" : "tags", "size" : 10} }
    }
}
'
{% endhighlight %}

你看到了，我接受所有文档，然后定义一个terms facet叫做“tags”。这个请求会返回如下样子的数据：

{% highlight javascript %}
{
    "took" : 2,
    // ... snip ...
    "hits" : {
        "total" : 4,
        // ... snip ...
    },
    "facets" : {
        "tags" : {
            "_type" : "terms",
            "missing" : 1,
            "terms" : [
                { "term" : "search", "count" : 4 },
                { "term" : "java",   "count" : 2 },
                { "term" : "ruby",   "count" : 1 },
                { "term" : "erlang", "count" : 1 }
            ]
        }
    }
}
{% endhighlight %}

JSON中`facets`部分是我们关心的，特别是`facets.tags.terms`数组。它告诉我们有四篇文章打了search标签，两篇java标签，等等…….(当然，我们或许应该给请求添加一个`size`参数跳过前面的结果)

这种比例类型的数据最合适的可视化方案就是饼图，或者它的变体：油炸圈饼图。最终结果如下(你可能希望看这个[可运行的实例](http://www.elasticsearch.cn/blog/assets/dashboards/donut.html))：

![图片3](http://www.elasticsearch.cn/blog/images/dashboards/donut_chart.png)

我们将使用[Protovis](http://vis.stanford.edu/protovis/)一个JavaScript的数据可视化工具集。Protovis是100%开源的，你可以想象它是数据可视化方面的RoR。和其他类似工具形成鲜明对比的是，它没有附带一组图标类型来供你“选择”。而是定义了一组原语和一个灵活的DSL，这样你可以非常简单的创建自定义的可视化。创建[饼图](http://vis.stanford.edu/protovis/ex/pie.html)就非常简单。

因为ES返回的是JSON数据，我们可以通过Ajax调用加载它。不要忘记你可以clone或者下载实例的[全部源代码](https://gist.github.com/966338)。

首先需要一个HTML文件来容纳图标然后从ES里加载数据：

{% highlight html %}
<!DOCTYPE html>
<html>
<head>
    <title>ElasticSearch Terms Facet Donut Chart</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

    <!-- Load JS libraries -->
    <script src="jquery-1.5.1.min.js"></script>
    <script src="protovis-r3.2.js"></script>
    <script src="donut.js"></script>
    <script>
        $( function() { load_data(); });

        var load_data = function() {
            $.ajax({   url: 'http://localhost:9200/dashboard/article/_search?pretty=true'
                     , type: 'POST'
                     , data : JSON.stringify({
                           "query" : { "match_all" : {} },

                           "facets" : {
                               "tags" : {
                                   "terms" : {
                                       "field" : "tags",
                                       "size"  : "10"
                                   }
                               }
                           }
                       })
                     , dataType : 'json'
                     , processData: false
                     , success: function(json, statusText, xhr) {
                           return display_chart(json);
                       }
                     , error: function(xhr, message, error) {
                           console.error("Error while loading data from ElasticSearch", message);
                           throw(error);
                       }
            });

            var display_chart = function(json) {
                Donut().data(json.facets.tags.terms).draw();
            };

        };
    </script>
</head>
<body>

  <!-- Placeholder for the chart -->
  <div id="chart"></div>

</body>
</html>
{% endhighlight %}

文档加载后，我们通过Ajax收到和之前`curl`测试中一样的facet。在jQuery的Ajaxcallback里我们通过封装的`display_chart()`把返回的JSON传给`Donut()`函数.

`Donut()`函数及注释如下： 

{% highlight javascript %}
// =====================================================================================================
// A donut chart with Protovis - See http://vis.stanford.edu/protovis/ex/pie.html
// =====================================================================================================
var Donut = function(dom_id) {

    if ('undefined' == typeof dom_id)  {                // Set the default DOM element ID to bind
        dom_id = 'chart';
    }

    var data = function(json) {                         // Set the data for the chart
        this.data = json;
        return this;
    };

    var draw = function() {

        var entries = this.data.sort( function(a, b) {  // Sort the data by term names, so the
            return a.term < b.term ? -1 : 1;            // color scheme for wedges is preserved
        }),                                             // with any order

        values  = pv.map(entries, function(e) {         // Create an array holding just the counts
            return e.count;
        });
        // console.log('Drawing', entries, values);

        var w = 200,                                    // Dimensions and color scheme for the chart
            h = 200,
            colors = pv.Colors.category10().range();

        var vis = new pv.Panel()                        // Create the basis panel
            .width(w)
            .height(h)
            .margin(0, 0, 0, 0);

        vis.add(pv.Wedge)                               // Create the "wedges" of the chart
            .def("active", -1)                          // Auxiliary variable to hold mouse over state
            .data( pv.normalize(values) )               // Pass the normalized data to Protovis
            .left(w/3)                                  // Set-up chart position and dimension
            .top(w/3)
            .outerRadius(w/3)
            .innerRadius(15)                            // Create a "donut hole" in the center
            .angle( function(d) {                       // Compute the "width" of the wedge
                return d * 2 * Math.PI;
             })
            .strokeStyle("#fff")                        // Add white stroke

            .event("mouseover", function() {            // On "mouse over", set the "wedge" as active
                this.active(this.index);
                this.cursor('pointer');
                return this.root.render();
             })

            .event("mouseout",  function() {            // On "mouse out", clear the active state
                this.active(-1);
                return this.root.render();
            })

            .event("mousedown", function(d) {           // On "mouse down", perform action,
                var term = entries[this.index].term;    // such as filtering the results...
                return (alert("Filter the results by '"+term+"'"));
            })


            .anchor("right").add(pv.Dot)                // Add the left part of he "inline" label,
                                                        // displayed inside the donut "hole"

            .visible( function() {                      // The label is visible when its wedge is active
                return this.parent.children[0]
                       .active() == this.index;
            })
            .fillStyle("#222")
            .lineWidth(0)
            .radius(14)

            .anchor("center").add(pv.Bar)               // Add the middle part of the label
            .fillStyle("#222")
            .width(function(d) {                        // Compute width:
                return (d*100).toFixed(1)               // add pixels for percents
                              .toString().length*4 +
                       10 +                             // add pixels for glyphs (%, etc)
                       entries[this.index]              // add pixels for letters (very rough)
                           .term.length*9;
            })
            .height(28)
            .top((w/3)-14)

            .anchor("right").add(pv.Dot)                // Add the right part of the label
            .fillStyle("#222")
            .lineWidth(0)
            .radius(14)


            .parent.children[2].anchor("left")          // Add the text to label
                   .add(pv.Label)
            .left((w/3)-7)
            .text(function(d) {                         // Combine the text for label
                return (d*100).toFixed(1) + "%" +
                       ' ' + entries[this.index].term +
                       ' (' + values[this.index] + ')';
            })
            .textStyle("#fff")

            .root.canvas(dom_id)                        // Bind the chart to DOM element
            .render();                                  // And render it.
    };

    return {                                            // Create the public API
        data   : data,
        draw   : draw
    };

};
{% endhighlight %}
现在你们看到了，一个简单的JSON数据转换，我们就可以创建出丰富的有吸引力的关于我们文章标签分布的可视化图标。完整的例子在[这里](http://www.elasticsearch.cn/blog/assets/dashboards/donut.html)。

当你使用完全不同的请求，比如显示某个特定作者的文章，或者特定日期内发表的文章，整个可视化都照样正常工作，代码是可以重用的。

# 日期直方图(date histogram facets)时间线

Protovis让创建另一种常见的可视化类型也非常容易：[时间线](http://vis.stanford.edu/protovis/ex/zoom.html)。任何类型的数据，只要和特定日期相关的，比如文章发表，事件发生，目标达成，都可以被可视化成时间线。

最终结果就像下面这样(同样可以看[运行版](http://www.elasticsearch.cn/blog/assets/dashboards/timeline.html))：

![图片4](http://www.elasticsearch.cn/blog/images/dashboards/timeline_chart.png)

好了，让我们往索引里存一些带有发表日期的文章吧：

{% highlight bash %}
curl -X DELETE "http://localhost:9200/dashboard"
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "1",  "published" : "2011-01-01" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "2",  "published" : "2011-01-02" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "3",  "published" : "2011-01-02" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "4",  "published" : "2011-01-03" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "5",  "published" : "2011-01-04" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "6",  "published" : "2011-01-04" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "7",  "published" : "2011-01-04" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "8",  "published" : "2011-01-04" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "9",  "published" : "2011-01-10" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "10", "published" : "2011-01-12" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "11", "published" : "2011-01-13" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "12", "published" : "2011-01-14" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "13", "published" : "2011-01-14" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "14", "published" : "2011-01-15" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "15", "published" : "2011-01-20" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "16", "published" : "2011-01-20" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "17", "published" : "2011-01-21" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "18", "published" : "2011-01-22" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "19", "published" : "2011-01-23" }'
curl -X POST "http://localhost:9200/dashboard/article" -d '{ "t" : "20", "published" : "2011-01-24" }'
curl -X POST "http://localhost:9200/dashboard/_refresh"
{% endhighlight %}

我们用ES的[date histogram facet](http://www.elasticsearch.org/guide/reference/api/search/facets/date-histogram-facet.html)来获取文章发表的频率。

{% highlight bash %}
curl -X POST "http://localhost:9200/dashboard/_search?pretty=true" -d '
{
    "query" : { "match_all" : {} },

    "facets" : {
        "published_on" : {
            "date_histogram" : {
                "field"    : "published",
                "interval" : "day"
            }
        }
    }
}
'
{% endhighlight %}

注意我们是怎么设置间隔为天的。这个很容易就可以替换成周，月 ，或者年。

请求会返回像下面这样的JSON：

{% highlight javascript %}
{
    "took" : 2,
    // ... snip ...
    "hits" : {
        "total" : 4,
        // ... snip ...
    },
    "facets" : {
        "published" : {
            "_type" : "histogram",
            "entries" : [
                { "time" : 1293840000000, "count" : 1 },
                { "time" : 1293926400000, "count" : 2 }
                // ... snip ...
            ]
        }
    }
}
{% endhighlight %}

我们要注意的是`facets.published.entries`数组，和上面的例子一样。同样需要一个HTML页来容纳图标和加载数据。机制既然一样，代码就直接看[这里](https://gist.github.com/900542/#file_chart.html)吧。

既然已经有了JSON数据，用protovis创建时间线就很简单了，用一个自定义的[area chart](http://vis.stanford.edu/protovis/ex/area.html)即可。

完整带注释的`Timeline()`函数如下：
{% highlight javascript %}
// =====================================================================================================
// A timeline chart with Protovis - See http://vis.stanford.edu/protovis/ex/area.html
// =====================================================================================================

var Timeline = function(dom_id) {
    if ('undefined' == typeof dom_id) {                 // Set the default DOM element ID to bind
        dom_id = 'chart';
    }

    var data = function(json) {                         // Set the data for the chart
        this.data = json;
        return this;
    };

    var draw = function() {

        var entries = this.data;                        // Set-up the data
            entries.push({                              // Add the last "blank" entry for proper
              count : entries[entries.length-1].count   // timeline ending
            });
        // console.log('Drawing, ', entries);

        var w = 600,                                    // Set-up dimensions and scales for the chart
            h = 100,
            max = pv.max(entries, function(d) {return d.count;}),
            x = pv.Scale.linear(0, entries.length-1).range(0, w),
            y = pv.Scale.linear(0, max).range(0, h);

        var vis = new pv.Panel()                        // Create the basis panel
            .width(w)
            .height(h)
            .bottom(20)
            .left(20)
            .right(40)
            .top(40);

         vis.add(pv.Label)                              // Add the chart legend at top left
            .top(-20)
            .text(function() {
                 var first = new Date(entries[0].time);
                 var last  = new Date(entries[entries.length-2].time);
                 return "Articles published between " +
                     [ first.getDate(),
                       first.getMonth() + 1,
                       first.getFullYear()
                     ].join("/") +

                     " and " +

                     [ last.getDate(),
                       last.getMonth() + 1,
                       last.getFullYear()
                     ].join("/");
             })
            .textStyle("#B1B1B1")

         vis.add(pv.Rule)                               // Add the X-ticks
            .data(entries)
            .visible(function(d) {return d.time;})
            .left(function() { return x(this.index); })
            .bottom(-15)
            .height(15)
            .strokeStyle("#33A3E1")

            .anchor("right").add(pv.Label)              // Add the tick label (DD/MM)
            .text(function(d) {
                 var date = new Date(d.time);
                 return [
                     date.getDate(),
                     date.getMonth() + 1
                 ].join('/');
             })
            .textStyle("#2C90C8")
            .textMargin("5")

         vis.add(pv.Rule)                               // Add the Y-ticks
            .data(y.ticks(max))                         // Compute tick levels based on the "max" value
            .bottom(y)
            .strokeStyle("#eee")
            .anchor("left").add(pv.Label)
                .text(y.tickFormat)
                .textStyle("#c0c0c0")

        vis.add(pv.Panel)                               // Add container panel for the chart
           .add(pv.Area)                                // Add the area segments for each entry
           .def("active", -1)                           // Auxiliary variable to hold mouse state
           .data(entries)                               // Pass the data to Protovis
           .bottom(0)
           .left(function(d) {return x(this.index);})   // Compute x-axis based on scale
           .height(function(d) {return y(d.count);})    // Compute y-axis based on scale
           .interpolate('cardinal')                     // Make the chart curve smooth
           .segmented(true)                             // Divide into "segments" (for interactivity)
           .fillStyle("#79D0F3")

           .event("mouseover", function() {             // On "mouse over", set segment as active
               this.active(this.index);
               return this.root.render();
           })

           .event("mouseout",  function() {             // On "mouse out", clear the active state
               this.active(-1);
               return this.root.render();
           })

           .event("mousedown", function(d) {            // On "mouse down", perform action,
               var time = entries[this.index].time;     // eg filtering the results...
               return (alert("Timestamp: '"+time+"'"));
           })

           .anchor("top").add(pv.Line)                  // Add thick stroke to the chart
           .lineWidth(3)
           .strokeStyle('#33A3E1')

           .anchor("top").add(pv.Dot)                   // Add the circle "label" displaying
                                                        // the count for this day

           .visible( function() {                       // The label is only visible when
               return this.parent.children[0]           // its segment is active
                          .active() == this.index;
            })
           .left(function(d) { return x(this.index); })
           .bottom(function(d) { return y(d.count); })
           .fillStyle("#33A3E1")
           .lineWidth(0)
           .radius(14)

           .anchor("center").add(pv.Label)             // Add text to the label
           .text(function(d) {return d.count;})
           .textStyle("#E7EFF4")

           .root.canvas(dom_id)                        // Bind the chart to DOM element
           .render();                                  // And render it.
    };

    return {                                            // Create the public API
        data   : data,
        draw   : draw
    };

};
{% endhighlight %}

完整示例代码在[这里](http://www.elasticsearch.cn/blog/assets/dashboards/timeline.html)。不过先去下载protovis提供的关于[area](http://vis.stanford.edu/protovis/docs/area.html)的原始文档，然后观察当你修改`interpolate('cardinal')`成`interpolate('step-after')`后发生了什么。对于多个facet，画叠加的区域图，添加交互性，然后完全定制可视化应该都不是什么问题了。

重要的是注意，这个图表完全是根据你传递给ES的请求做出的响应，使得你有可能做到简单立刻的完成某项指标的可视化需求。比如“显示这个作者在这个主题上最近三个月的出版频率”。只需要提交这样的请求就够了：

{% highlight bash %}
 author:John AND topic:Search AND published:[2011-03-01 TO 2011-05-31]
{% endhighlight %}

# 总结

当你需要为复杂的自定义查询做一个丰富的交互式的数据可视化时，使用ES的facets应该是最容易的办法之一，你只需要传递ES的JSON响应给[Protovis](http://vis.stanford.edu/protovis/)这样的工具就好了。

通过模仿本文中的方法和代码，你可以在几小时内给你的数据跑通一个示例。
