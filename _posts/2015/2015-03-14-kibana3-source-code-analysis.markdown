---
layout: post
title: Kibana 3 源码解析
category: logstash
tags:
  - kibana
  - angularjs
---

本文之前已经拆分成章节发布在我的 [《Kibana 权威指南》电子书](http://kibana.logstash.es/)上。欢迎移步观看全书其他章节。

---------------------

Kibana 3 作为 ELKstack 风靡世界的最大推动力，其与优美的界面配套的简洁的代码同样功不可没。事实上，graphite 社区就通过移植 kibana 3 代码框架的方式，启动了 [grafana 项目](http://grafana.org/)。至今你还能在 grafana 源码找到二十多处 "kbn" 字样。

*巧合的是，在 Kibana 重构 v4 版的同时，grafana 的 v2 版也到了 Alpha 阶段，从目前的预览效果看，主体 dashboard 沿用了 Kibana 3 的风格，不过添加了额外的菜单栏，供用户权限设置等使用 —— 这意味着 grafana 2 跟 kibana 4 一样需要一个单独的 server 端。*

笔者并非专业的前端工程师，对 angularjs 也处于一本入门指南都没看过的水准。所以本节内容，只会抽取一些个人经验中会有涉及到的地方提出一些"私货"。欢迎方家指正。

## 源码目录结构

下面是 kibana 源码的全部文件的 tree 图：

    .
    ├── app
    │   ├── app.js
    │   ├── components
    │   │   ├── extend-jquery.js
    │   │   ├── kbn.js
    │   │   ├── lodash.extended.js
    │   │   ├── require.config.js
    │   │   └── settings.js
    │   ├── controllers
    │   │   ├── all.js
    │   │   ├── dash.js
    │   │   ├── dashLoader.js
    │   │   ├── pulldown.js
    │   │   └── row.js
    │   ├── dashboards
    │   │   ├── blank.json
    │   │   ├── default.json
    │   │   ├── guided.json
    │   │   ├── logstash.js
    │   │   ├── logstash.json
    │   │   ├── noted.json
    │   │   ├── panel.js
    │   │   └── test.json
    │   ├── directives
    │   │   ├── addPanel.js
    │   │   ├── all.js
    │   │   ├── arrayJoin.js
    │   │   ├── configModal.js
    │   │   ├── confirmClick.js
    │   │   ├── dashUpload.js
    │   │   ├── esVersion.js
    │   │   ├── kibanaPanel.js
    │   │   ├── kibanaSimplePanel.js
    │   │   ├── ngBlur.js
    │   │   ├── ngModelOnBlur.js
    │   │   ├── resizable.js
    │   │   └── tip.js
    │   ├── factories
    │   │   └── store.js
    │   ├── filters
    │   │   └── all.js
    │   ├── panels
    │   │   ├── bettermap
    │   │   │   ├── editor.html
    │   │   │   ├── leaflet
    │   │   │   │   ├── images
    │   │   │   │   │   ├── layers-2x.png
    │   │   │   │   │   ├── layers.png
    │   │   │   │   │   ├── marker-icon-2x.png
    │   │   │   │   │   ├── marker-icon.png
    │   │   │   │   │   └── marker-shadow.png
    │   │   │   │   ├── leaflet-src.js
    │   │   │   │   ├── leaflet.css
    │   │   │   │   ├── leaflet.ie.css
    │   │   │   │   ├── leaflet.js
    │   │   │   │   ├── plugins.css
    │   │   │   │   ├── plugins.js
    │   │   │   │   └── providers.js
    │   │   │   ├── module.css
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── column
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   └── panelgeneral.html
    │   │   ├── dashcontrol
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── derivequeries
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── fields
    │   │   │   ├── editor.html
    │   │   │   ├── micropanel.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── filtering
    │   │   │   ├── editor.html
    │   │   │   ├── meta.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── force
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── goal
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── histogram
    │   │   │   ├── editor.html
    │   │   │   ├── interval.js
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   ├── queriesEditor.html
    │   │   │   ├── styleEditor.html
    │   │   │   └── timeSeries.js
    │   │   ├── hits
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── map
    │   │   │   ├── editor.html
    │   │   │   ├── lib
    │   │   │   │   ├── jquery.jvectormap.min.js
    │   │   │   │   ├── map.cn.js
    │   │   │   │   ├── map.europe.js
    │   │   │   │   ├── map.usa.js
    │   │   │   │   └── map.world.js
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── multifieldhistogram
    │   │   │   ├── editor.html
    │   │   │   ├── interval.js
    │   │   │   ├── markersEditor.html
    │   │   │   ├── meta.html
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   ├── styleEditor.html
    │   │   │   └── timeSeries.js
    │   │   ├── percentiles
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── query
    │   │   │   ├── editor.html
    │   │   │   ├── editors
    │   │   │   │   ├── lucene.html
    │   │   │   │   ├── regex.html
    │   │   │   │   └── topN.html
    │   │   │   ├── help
    │   │   │   │   ├── lucene.html
    │   │   │   │   ├── regex.html
    │   │   │   │   └── topN.html
    │   │   │   ├── helpModal.html
    │   │   │   ├── meta.html
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   └── query.css
    │   │   ├── ranges
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── sparklines
    │   │   │   ├── editor.html
    │   │   │   ├── interval.js
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   └── timeSeries.js
    │   │   ├── statisticstrend
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── stats
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── table
    │   │   │   ├── editor.html
    │   │   │   ├── export.html
    │   │   │   ├── micropanel.html
    │   │   │   ├── modal.html
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   └── pagination.html
    │   │   ├── terms
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── text
    │   │   │   ├── editor.html
    │   │   │   ├── lib
    │   │   │   │   └── showdown.js
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   ├── timepicker
    │   │   │   ├── custom.html
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   ├── module.js
    │   │   │   └── refreshctrl.html
    │   │   ├── trends
    │   │   │   ├── editor.html
    │   │   │   ├── module.html
    │   │   │   └── module.js
    │   │   └── valuehistogram
    │   │       ├── editor.html
    │   │       ├── module.html
    │   │       ├── module.js
    │   │       ├── queriesEditor.html
    │   │       └── styleEditor.html
    │   ├── partials
    │   │   ├── connectionFailed.html
    │   │   ├── dashLoader.html
    │   │   ├── dashLoaderShare.html
    │   │   ├── dashboard.html
    │   │   ├── dasheditor.html
    │   │   ├── inspector.html
    │   │   ├── load.html
    │   │   ├── modal.html
    │   │   ├── paneladd.html
    │   │   ├── paneleditor.html
    │   │   ├── panelgeneral.html
    │   │   ├── querySelect.html
    │   │   └── roweditor.html
    │   └── services
    │       ├── alertSrv.js
    │       ├── all.js
    │       ├── dashboard.js
    │       ├── esVersion.js
    │       ├── fields.js
    │       ├── filterSrv.js
    │       ├── kbnIndex.js
    │       ├── monitor.js
    │       ├── panelMove.js
    │       ├── querySrv.js
    │       └── timer.js
    ├── config.js
    ├── css
    │   ├── angular-multi-select.css
    │   ├── animate.min.css
    │   ├── bootstrap-responsive.min.css
    │   ├── bootstrap.dark.min.css
    │   ├── bootstrap.light.min.css
    │   ├── font-awesome.min.css
    │   ├── jquery-ui.css
    │   ├── jquery.multiselect.css
    │   ├── normalize.min.css
    │   └── timepicker.css
    ├── favicon.ico
    ├── font
    │   ├── FontAwesome.otf
    │   ├── fontawesome-webfont.eot
    │   ├── fontawesome-webfont.svg
    │   ├── fontawesome-webfont.ttf
    │   └── fontawesome-webfont.woff
    ├── img
    │   ├── annotation-icon.png
    │   ├── cubes.png
    │   ├── glyphicons-halflings-white.png
    │   ├── glyphicons-halflings.png
    │   ├── kibana.png
    │   ├── light.png
    │   ├── load.gif
    │   ├── load_big.gif
    │   ├── small.png
    │   └── ui-icons_222222_256x240.png
    ├── index.html
    └── vendor
        ├── LICENSE.json
        ├── angular
        │   ├── angular-animate.js
        │   ├── angular-cookies.js
        │   ├── angular-dragdrop.js
        │   ├── angular-loader.js
        │   ├── angular-resource.js
        │   ├── angular-route.js
        │   ├── angular-sanitize.js
        │   ├── angular-scenario.js
        │   ├── angular-strap.js
        │   ├── angular.js
        │   ├── bindonce.js
        │   ├── datepicker.js
        │   └── timepicker.js
        ├── blob.js
        ├── bootstrap
        │   ├── bootstrap.js
        │   └── less
        │       ├── accordion.less
        │       ├── alerts.less
        │       ├── bak
        │       │   ├── bootswatch.dark.less
        │       │   └── variables.dark.less
        │       ├── bootstrap.dark.less
        │       ├── bootstrap.less
        │       ├── bootstrap.light.less
        │       ├── bootswatch.dark.less
        │       ├── bootswatch.light.less
        │       ├── breadcrumbs.less
        │       ├── button-groups.less
        │       ├── buttons.less
        │       ├── carousel.less
        │       ├── close.less
        │       ├── code.less
        │       ├── component-animations.less
        │       ├── dropdowns.less
        │       ├── forms.less
        │       ├── grid.less
        │       ├── hero-unit.less
        │       ├── labels-badges.less
        │       ├── layouts.less
        │       ├── media.less
        │       ├── mixins.less
        │       ├── modals.less
        │       ├── navbar.less
        │       ├── navs.less
        │       ├── overrides.less
        │       ├── pager.less
        │       ├── pagination.less
        │       ├── popovers.less
        │       ├── progress-bars.less
        │       ├── reset.less
        │       ├── responsive-1200px-min.less
        │       ├── responsive-767px-max.less
        │       ├── responsive-768px-979px.less
        │       ├── responsive-navbar.less
        │       ├── responsive-utilities.less
        │       ├── responsive.less
        │       ├── scaffolding.less
        │       ├── sprites.less
        │       ├── tables.less
        │       ├── tests
        │       │   ├── buttons.html
        │       │   ├── css-tests.css
        │       │   ├── css-tests.html
        │       │   ├── forms-responsive.html
        │       │   ├── forms.html
        │       │   ├── navbar-fixed-top.html
        │       │   ├── navbar-static-top.html
        │       │   └── navbar.html
        │       ├── thumbnails.less
        │       ├── tooltip.less
        │       ├── type.less
        │       ├── utilities.less
        │       ├── variables.dark.less
        │       ├── variables.less
        │       ├── variables.light.less
        │       └── wells.less
        ├── chromath.js
        ├── elasticjs
        │   ├── elastic-angular-client.js
        │   └── elastic.js
        ├── elasticsearch.angular.js
        ├── filesaver.js
        ├── jquery
        │   ├── jquery-1.8.0.js
        │   ├── jquery-ui-1.10.3.js
        │   ├── jquery.flot.byte.js
        │   ├── jquery.flot.events.js
        │   ├── jquery.flot.js
        │   ├── jquery.flot.pie.js
        │   ├── jquery.flot.selection.js
        │   ├── jquery.flot.stack.js
        │   ├── jquery.flot.stackpercent.js
        │   ├── jquery.flot.threshold.js
        │   ├── jquery.flot.time.js
        │   ├── jquery.multiselect.filter.js
        │   └── jquery.multiselect.js
        ├── jsonpath.js
        ├── lodash.js
        ├── modernizr-2.6.1.js
        ├── moment.js
        ├── numeral.js
        ├── require
        │   ├── css-build.js
        │   ├── css.js
        │   ├── require.js
        │   ├── text.js
        │   └── tmpl.js
        ├── simple_statistics.js
        ├── timezone.js
        └── underscore.string.js

一目了然，我们可以归纳出下面几类主要文件：

* 入口：index.html
* 模块库：vendor/
* 程序入口：app/app.js
* 组件配置：app/components/
* 仪表板控制：app/controllers/
* 挂件页面：app/partials/
* 服务：app/services/
* 指令：app/directives/
* 图表：app/panels/

## 入口和模块依赖

这一部分是网页项目的基础。从 index.html 里就可以学到 angularjs 最基础的常用模板语法了。出现的指令有：`ng-repeat`, `ng-controller`, `ng-include`, `ng-view`, `ng-slow`, `ng-click`, `ng-href`，以及变量绑定的语法：`{{ dashboard.current.** }}`。

index.html 中，需要注意 js 的加载次序，先 `require.js`，然后再 `require.config.js`，最后 `app`。整个 kibana 项目都是通过 **requrie** 方式加载的。而具体的模块，和模块的依赖关系，则定义在 `require.config.js` 里。这些全部加载完成后，才是启动 app 模块，也就是项目本身的代码。

require.config.js 中，主要分成两部分配置，一个是 `paths`，一个是 `shim`。paths 用来指定依赖模块的导出名称和模块 js 文件的具体路径。而 shim 用来指定依赖模块之间的依赖关系。比方说：绘制图表的 js，kibana3 里用的是 jquery.flot 库。这个就首先依赖于 jquery 库。(通俗的说，就是原先普通的 HTML 写法里，要先加载 jquery.js 再加载 jquery.flot.js)

在整个 paths 中，需要单独提一下的是 `elasticjs:'../vendor/elasticjs/elastic-angular-client'`。这是串联 elastic.js 和 angular.js 的文件。这里面实际是定义了一个 angular.module 的 factory，名叫 `ejsResource`。后续我们在 kibana 3 里用到的跟 Elasticsearch 交互的所有方法，都在这个 `ejsResource` 里了。

*factory 是 angular 的一个单例对象，创建之后会持续到你关闭浏览器。Kibana 3 就是通过这种方式来控制你所有的图表是从同一个 Elasticsearch 获取的数据*

app.js 中，定义了整个应用的 routes，加载了 controller, directives 和 filters 里的全部内容。就是在这里，加载了主页面 `app/partials/dashboard.html`。当然，这个页面其实没啥看头，因为里面就是提供 pulldown 和 row 的 div，然后绑定到对应的 controller 上。

## controller 和 service

controller 里没太多可讲的。kibana 3 里，pulldown 其实跟 row 差别不大，看这简单的几行代码里，最关键的就是几个注入：

{% highlight javascript %}
define(['angular','app','lodash'], function (angular, app, _) {
  'use strict';
  angular.module('kibana.controllers').controller('RowCtrl', function($scope, $rootScope, $timeout,ejsResource, querySrv) {
      var _d = {
        title: "Row",
        height: "150px",
        collapse: false,
        collapsable: true,
        editable: true,
        panels: [],
        notice: false
      };
      _.defaults($scope.row,_d);

      $scope.init = function() {
        $scope.querySrv = querySrv;
        $scope.reset_panel();
      };
      $scope.init();
    }
  );
});
{% endhighlight %}

这里面，注入了 `$scope`, `ejsResource` 和 `querySrv`。`$scope` 是控制器作用域内的模型数据对象，这是 angular 提供的一个特殊变量。`ejsResource` 是一个 factory ，前面已经讲过。`querySrv` 是一个 service，下面说一下。

service 跟 factory 的概念非常类似，一般来说，可能 factory 偏向用来共享一个类，而 service 用来共享一组函数功能。

kibana 3 里，比较有用和常用的 services 包括：

### dashboard

dashboard.js 里提供了关于 Kibana 3 仪表板的读写操作。其中主要的几个是提供了三种读取仪表板布局纲要的方式，也就是读取文件，读取存在 `.kibana-int` 索引里的数据，读取 js 脚本。下面是读取 js 脚本的相关函数：

{% highlight javascript %}
    this.script_load = function(file) {
      return $http({
        url: "app/dashboards/"+file.replace(/\.(?!js)/,"/"),
        method: "GET",
        transformResponse: function(response) {
          /*jshint -W054 */
          var _f = new Function('ARGS','kbn','_','moment','window','document','angular','require','define','$','jQuery',response);
          return _f($routeParams,kbn,_,moment);
        }
      }).then(function(result) {
        if(!result) {
          return false;
        }
        self.dash_load(dash_defaults(result.data));
        return true;
      },function() {
        alertSrv.set('Error',
          "Could not load <i>scripts/"+file+"</i>. Please make sure it exists and returns a valid dashboard" ,
          'error');
        return false;
      });
    };
{% endhighlight %}

可以看到，最关键的就是那个 `new Function`。知道这步传了哪些函数进去，也就知道你的 js 脚本里都可以调用哪些内容了~

最后调用的 `dash_load` 方法也需要提一下。这个方法的最后，有几行这样的代码：

{% highlight javascript %}
      self.availablePanels = _.difference(config.panel_names,
        _.pluck(_.union(self.current.nav,self.current.pulldowns),'type'));

      self.availablePanels = _.difference(self.availablePanels,config.hidden_panels);
{% endhighlight %}

从最外层的 `config.js` 里读取了 `panel_names` 数组，然后取出了 nav 和 pulldown 用过的 panel，剩下就是我们能在 row 里添加的 panel 类型了。

### querySrv

querySrv.js 里定义了跟 query 框相关的函数和属性。主要有几个值得注意的。

* 一个是 `color` 列表；
* 一个是 `queryTypes`，尤其是里么的 `topN`，可以看到 topN 方式其实就是先请求了一次 termsFacet，然后把结果 map 成一组普通的 query。
* 一个是 `ids` 和 `idsByMode`。之后图表的绑定具体 query 的时候，就是通过这个函数来选择的。

### filterSrv

filterSrv.js 跟 querySrv 相似。特殊的是两个函数。

* 一个是 `toEjsObjs`。根据不同的 filter 类型调用不同的 ejs 方法。
* 一个是 `timeRange`。因为在 histogram panel 上拖拽，会生成好多个 range 过滤器，都是时间。这个方法会选择最后一个类型为 time 的 filter，作为实际要用的 filter。这样保证请求 ES 的是最后一次拖拽选定的时间段。

### fields

fields.js 里最重要的作用就是通过 mapping 接口获取索引的字段列表，存在 `fields.list` 里。这个数组后来在每个 panel 的编辑页里，都以 `bs-typeahead="fields.list"` 的形式作为文本输入时的自动补全提示。在 table panel 里，则是左侧栏的显示来源。

### esVersion

esVersion.js 里提供了对 ES 版本号的对比函数。之所以专门提供这么个 service，一来是因为不同版本的 ES 接口有变化，比如我自己开发的 percentile panel 里，就用 esVersion 判断了两次版本。因为 percentile 接口是 1.0 版之后才有，而从 1.3 版以后返回数据的结构又发生了一次变动。二来 ES 的版本号格式比较复杂，又有点又有字母。

## panel 相关指令

### 添加 panel

前面在讲 `app/services/dashboard.js` 的时候，已经说到能添加的 panel 列表是怎么获取的。那么panel 是怎么加上的呢？

同样是之前讲过的 `app/partials/dashaboard.html` 里，加载了 `partials/roweditor.html` 页面。这里有一段：

{% highlight html %}
    <form class="form-inline">
      <select class="input-medium" ng-model="panel.type" ng-options="panelType for panelType in dashboard.availablePanels|stringSort"></select>
      <small ng-show="rowSpan(row) > 11">
        Note: This row is full, new panels will wrap to a new line. You should add another row.
      </small>
    </form>

    <div ng-show="!(_.isUndefined(panel.type))">
      <div add-panel="{{panel.type}}"></div>
    </div>
{% endhighlight %}

这个 `add-panel` 指令，是有 `app/directives/addPanel.js` 提供的。方法如下：

{% highlight javascript %}
          $scope.$watch('panel.type', function() {
            var _type = $scope.panel.type;
            $scope.reset_panel(_type);
            if(!_.isUndefined($scope.panel.type)) {
              $scope.panel.loadingEditor = true;
              $scope.require(['panels/'+$scope.panel.type.replace(".","/") +'/module'], function () {
                var template = '<div ng-controller="'+$scope.panel.type+'" ng-include="\'app/partials/paneladd.html\'"></div>';
                elem.html($compile(angular.element(template))($scope));
                $scope.panel.loadingEditor = false;
              });
            }
          });
{% endhighlight %}

可以看到，其实就是 require 了对应的 `panels/xxx/module.js`，然后动态生成一个 div，绑定到对应的 controller 上。

### 展示 panel

还是在 `app/partials/dashaboard.html` 里，用到了另一个指令 `kibana-panel`：

{% highlight html %}
            <div
              ng-repeat="(name, panel) in row.panels|filter:isPanel"
              ng-cloak ng-hide="panel.hide"
              kibana-panel type='panel.type' resizable
              class="panel nospace" ng-class="{'dragInProgress':dashboard.panelDragging}"
              style="position:relative"  ng-style="{'width':!panel.span?'100%':((panel.span/1.2)*10)+'%'}"
              data-drop="true" ng-model="row.panels" data-jqyoui-options
              jqyoui-droppable="{index:$index,mutate:false,onDrop:'panelMoveDrop',onOver:'panelMoveOver(true)',onOut:'panelMoveOut'}">
            </div>
{% endhighlight %}

当然，这里面还有 `resizable` 指令也是自己实现的，不过一般我们用不着关心这个的代码实现。

下面看 `app/directives/kibanaPanel.js` 里的实现。

这个里面大多数逻辑跟 addPanel.js 是一样的，都是为了实现一个指令嘛。对于我们来说，关注点在前面那一大段 HTML 字符串，也就是变量 `panelHeader`。这个就是我们看到的实际效果中，kibana 3 每个 panel 顶部那个小图标工具栏。仔细阅读一下，可以发现除了每个 panel 都一致的那些 span 以外，还有一段是：

{% highlight javascript %}
           '<span ng-repeat="task in panelMeta.modals" class="row-button extra" ng-show="task.show">' +
              '<span bs-modal="task.partial" class="pointer"><i ' +
                'bs-tooltip="task.description" ng-class="task.icon" class="pointer"></i></span>'+
            '</span>'
{% endhighlight %}

也就是说，每个 panel 可以在自己的 panelMeta.modals 数组里，定义不同的小图标，弹出不同的对话浮层。我个人给 table panel 二次开发加入的 exportAsCsv 功能，图标就是在这里加入的。

## panel 内部实现

终于说到最后了。大家进入到 `app/panels/` 下，每个目录都是一种 panel。原因前一节已经分析过了，因为 addPanel.js 里就是直接这样拼接的。入口都是固定的：module.js。

下面以 stats panel 为例。(因为我最开始就是抄的 stats 做的 percentile，只有表格没有图形，最简单)

每个目录下都会有至少一下三个文件：

### module.js

module.js 就是一个 controller。跟前面讲过的 controller 写法其实是一致的。在 `$scope` 对象上，有几个属性是 panel 实现时一般都会有的：

* `$scope.panelMeta`: 这个前面说到过，其中的 modals 用来定义 panelHeader。
* `$scope.panel`: 用来定义 panel 的属性。一般实现上，会有一个 default 值预定义好。你会发现这个 `$scope.panel` 其实就是仪表板纲要里面说的每个 panel 的可设置值！

然后一般 `$scope.init()` 都是这样的：

{% highlight javascript %}
    $scope.init = function () {
      $scope.ready = false;
      $scope.$on('refresh', function () {
        $scope.get_data();
      });
      $scope.get_data();
    };
{% endhighlight %}

也就是每次有刷新操作，就执行 `get_data()` 方法。这个方法就是获取 ES 数据，然后渲染效果的入口。

{% highlight javascript %}
    $scope.get_data = function () {
      if(dashboard.indices.length === 0) {
        return;
      }

      $scope.panelMeta.loading = true;

      var request,
        results,
        boolQuery,
        queries;

      request = $scope.ejs.Request();

      $scope.panel.queries.ids = querySrv.idsByMode($scope.panel.queries);
      queries = querySrv.getQueryObjs($scope.panel.queries.ids);

      boolQuery = $scope.ejs.BoolQuery();
      _.each(queries,function(q) {
        boolQuery = boolQuery.should(querySrv.toEjsObj(q));
      });

      request = request
        .facet($scope.ejs.StatisticalFacet('stats')
          .field($scope.panel.field)
          .facetFilter($scope.ejs.QueryFilter(
            $scope.ejs.FilteredQuery(
              boolQuery,
              filterSrv.getBoolFilter(filterSrv.ids())
              )))).size(0);

      _.each(queries, function (q) {
        var alias = q.alias || q.query;
        var query = $scope.ejs.BoolQuery();
        query.should(querySrv.toEjsObj(q));
        request.facet($scope.ejs.StatisticalFacet('stats_'+alias)
          .field($scope.panel.field)
          .facetFilter($scope.ejs.QueryFilter(
            $scope.ejs.FilteredQuery(
              query,
              filterSrv.getBoolFilter(filterSrv.ids())
            )
          ))
        );
      });

      $scope.inspector = request.toJSON();

      results = $scope.ejs.doSearch(dashboard.indices, request);

      results.then(function(results) {
        $scope.panelMeta.loading = false;
        var value = results.facets.stats[$scope.panel.mode];

        var rows = queries.map(function (q) {
          var alias = q.alias || q.query;
          var obj = _.clone(q);
          obj.label = alias;
          obj.Label = alias.toLowerCase(); //sort field
          obj.value = results.facets['stats_'+alias];
          obj.Value = results.facets['stats_'+alias]; //sort field
          return obj;
        });

        $scope.data = {
          value: value,
          rows: rows
        };

        $scope.$emit('render');
      });
    };
{% endhighlight %}

stats panel 的这段函数几乎就跟基础示例一样了。

1. 生成 Request 对象。
2. 获取关联的 query 对象。
3. 获取当前页的 filter 对象。
4. 调用选定的 facets 方法，传入参数。
5. 如果有多个 query，逐一构建 facets。
6. request 完成。生成一个 JSON 内容供 inspector 查看。
7. 发送请求，等待异步回调。
8. 回调处理数据成绑定在模板上的 `$scope.data`。
9. 渲染页面。

注：stats/module.js 后面还有一个 filter，terms/module.js 后面还有一个 directive，这些都是为了实际页面效果加的功能，跟 kibana 本身的 filter，directive 本质上是一样的。就不单独讲述了。

### module.html

module.html 就是 panel 的具体页面内容。没有太多可说的。大概框架是：

{% highlight html %}
<div ng-controller='stats' ng-init="init()">
 <table ng-style="panel.style" class="table table-striped table-condensed" ng-show="panel.chart == 'table'">
    <thead>
      <th>Term</th> <th>{{ panel.tmode == 'terms_stats' ? panel.tstat : 'Count' }}</th> <th>Action</th>
    </thead>
    <tr ng-repeat="term in data" ng-show="showMeta(term)">
      <td class="terms-legend-term">{{term.label}}</td>
      <td>{{term.data[0][1]}}</td>
    </tr>
  </table>
</div>
{% endhighlight %}

主要就是绑定要 controller 和 init 函数。对于示例的 stats，里面的 `data` 就是 module.js 最后生成的 `$scope.data`。

### editor.html

editor.html 是 panel 参数的编辑页面主要内容，参数编辑还有一些共同的标签页，是在 kibana 的 `app/partials/` 里，就不讲了。

editor.html 里，主要就是提供对 `$scope.panel` 里那些参数的修改保存操作。当然实际上并不是所有参数都暴露出来了。这也是 kibana 3 用户指南里，官方说采用仪表板纲要，比通过页面修改更灵活细腻的原因。

editor.html 里需要注意的是，为了每次变更都能实时生效，所有的输入框都注册到了刷新事件。所以一般是这样子：

{% highlight html %}
      <select ng-change="set_refresh(true)" class="input-small" ng-model="panel.format" ng-options="f for f in ['number','float','money','bytes']"></select>
{% endhighlight %}

这个 `set_refresh` 函数是在 `module.js` 里定义的：

{% highlight javascript %}
    $scope.set_refresh = function (state) {
      $scope.refresh = state;
    };
{% endhighlight %}

## 总结

kibana 3 源码的主体分析，就是这样了。怎么样，看完以后，大家有没有信心也做些二次开发，甚至跟 grafana 一样，替换掉 esResource，换上一个你自己的后端数据源呢？

