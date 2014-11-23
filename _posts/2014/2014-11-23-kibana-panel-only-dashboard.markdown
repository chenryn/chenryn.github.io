---
layout: post
title: 利用动态仪表板实现kibana单图表导出功能
category: logstash
tags:
  - javascript
  - kibana
---

昨天和朋友聊天，说监控报表的话题，他们认为 kibana 的仪表板形式，还是偏重技术人员做监控的 screen 思路，对 erp 之类的报表不是很友好。要想跟其他系统结合，或者说嵌入到其他系统中，就必须得有单个图表的导出，或者 URL 引用方式。当时我直觉上的反应，就是这个没问题，可以通过 javascript 动态仪表板这个高级功能完成。回来试了一下，比我想的稍微复杂一点点，还是可以很轻松完成的。

读过[仪表板纲要](http://kibana.logstash.es/content/dashboard-schema.html)一文，或者自己看过源代码中 `src/app/dashboards/logstash.json` 文件的人，应该都知道 kibana 中有些在页面配置界面里看不到的隐藏配置选项。其中很符合我们这次需求的，就有 `editable`, `collapsable` 等。所以，首先第一步，我们可以在自己的 `panel.js`(直接从 logstash.js 复制过来) 中，把这些关掉：

{% highlight javascript %}
dashboard.rows = [
  {
    editable: false,         //不显示每行的编辑按钮
    collapsable: false,      //不显示每行的折叠按钮
    title: "Events",
    height: "400px",
    panels = [{
      editable: false,       //不显示面板的编辑按钮
      title: 'events over time',
      type: 'histogram',
      time_field: ARGS.timefield||"@timestamp",
      auto_int: true,
      span: 12
    }]
  }
];
dashboard.editable = false;     //不显示仪表板的编辑按钮
dashboard.panel_hints = false;  //不显示面板的添加按钮
{% endhighlight %}

然后要解决面板上方的 query 框和 filtering 框。这个同样在纲要介绍里说了，这两个特殊的面板是放在垂幕(pulldows)里的。所以，直接关掉垂幕就好了：

{% highlight javascript %}
dashboard.pulldowns = [];
{% endhighlight %}

然后再往上是顶部栏。顶部栏里有时间选择器，这个跟垂幕一样是可以关掉的：

{% highlight javascript %}
dashboard.nav = [];
{% endhighlight %}

好了，javascript 里可以关掉的，都已经关了。

但是运行起来，发现顶部栏里虽然是没有时间选择器和配置编辑按钮了，本身这个黑色条带和 logo 图什么的，却依然存在！这时候我想起来有时候 config.js 没写对，`/_nodes` 获取失败的时候，打开的页面就是背景色外加这个顶条 —— 也就是说，这部分代码是写在 `index.html` 里的，不受 `app/dashboards/panel.js` 控制。

所以这里就得去修改一下 `index.html` 了。不过为了保持兼容性，我这里没有直接删除顶部栏的代码，而是用了 angularjs 中很常用的 `ng-show` 指令：

{% highlight html %}
<div ng-cloak class="navbar navbar-static-top" ng-show="dashboard.current.nav.length">
{% endhighlight %}

因为之前关闭时间选择器的时候，已经把这个 nav 数组定义为空了，所以只要判断一下数组长度即可。

效果如下：

![single panel](http://photo.weibo.com/1035836154/wbphotos/large/mid/3780159570052868/pid/3dbd9afagw1eml6f9xqltj20lc0fuwfu)

因为 `dashboard.services` 的定义没有做修改，所以这个其实照样支持你用鼠标拉动选择时间范围，支持你在 URL 后面加上 `?query=status:404&from=1h` 这样的参数，效果都是对的。只不过不会再让你看到这些文字显示在页面上了。

如果要求再高一点，其实完全可以在 `ARGS` 里处理更复杂的参数，比如直接 `?type=terms&field=host&value_field=requesttime` 就生成 `dashboard.rows[0].panels[0]` 里的对应参数，达到自动控制图表类型和效果的目的。
