---
layout: post
title: 给 Kibana3 添加脚本化字段支持
category: logstash
tags:
  - kibana
  - elasticsearcch
  - javascript
---

Kibana4 中确实有不少让人眼前一亮的新特性，但是整体框架和使用思路上的重构实在让人较难上手。所以，把一些有需要的特性，port 回目前更稳定的 Kibana3 就有必要了。好在去年在自己 fork 中已经做了很多铺垫，包括一些基础库的版本更新。这些特性基本都只需要几行代码的变动就可以实现。

从上次写博客介绍的 uniq histogram 去重统计功能后，这段时间又添加了两个功能。

## table 的数据导出

kibana3 已经带有 [filesaver.js](https://github.com/eligrey/FileSaver.js)，所以加一个 `exportAsCsv` 函数即可。要点在于怎么给 table panel 右上角那排小按钮加上一个新图标。

我之前说过，kibana3 代码划分的很细致，每个 panel 都固定只需要提供 editor.html，module.html，module.js 三个文件即可。panel 本身的框架，是不用关心的。因为这部分代码，在 `app/directives/kibanaPanel.js` 中。这次我们想修改 panel 外围的样式，就需要来看这个的代码了。最关键的部分在这里：

```javascript
            '<span ng-repeat="task in panelMeta.modals" class="row-button extra" ng-show="task.show">' +
              '<span bs-modal="task.partial" class="pointer"><i ' +
                'bs-tooltip="task.description" ng-class="task.icon" class="pointer"></i></span>'+
            '</span>' +
```

也就是说，它会读取你在 module.js 里定义的 `$scope.panelMeta.modals` 数组，然后依次显示。那么就好办了，在我们 table/module.js 里定义下就好了：

```javascript
     $scope.panelMeta = {
       modals : [
         {
          description: "Export",
          icon: "icon-download-alt",
          partial: "app/panels/table/export.html",
          show: $scope.panel.exportable
        },
```

为了跟其他的比如 inspector, editor 图标行为一致，这里又新增了一个 `$scope.panel.exportable` 变量。而这也带来一个问题：之前已经存在的 dashboard，他们的 schema 里是没有这个变量的，所以即便使用带有这个特性的 kibana 打开老 dashboard，依然看不到导出按钮。这时候，可以手动修改一下 schema 的 JSON 内容，添加上一行 [`"exportable": true`](https://github.com/chenryn/kibana-authorization/blob/master/src/app/dashboards/logstash.json#L138)，也可以点击 panel 上的 dup 复制按钮，复制出来的 panel 会读取默认变量设置，就会出现导出按钮了。然后删掉原 panel ，保存 dashboard 即可。

**注意**：导出的数据只是 table 里的内容，这只是一个 js 功能。不要把它理解成调用 scroll API 获取 Elasticsearch 集群里的全部数据。

## scriptField 聚合

Kibana4beta3 的另一个重要特性，是可以预定义一段 script 为 scriptedField，然后在搜索、聚合的时候可以当做普通 field 一样使用这个 scriptedField。示例见官方博客说明(可以直接看[我的翻译](http://chenlinux.com/2014/12/19/kibana-4-beta-3-now-more-filtery/))。至于 script 本身能在 Elasticsearch 里做些什么，之前博客里也写过[两个小示例](http://chenlinux.com/2014/11/27/elasticsearch-scripts-aggregations/)。

*动态 script 功能在 ES 1.4 之前是因为安全问题被建议关闭的。1.4 开始加入了沙箱功能，才这么大胆的使用。*

我印象中 script field 应该是不能保存在 mapping 里的，于是稍微看了一下 kibana4 的代码，疑似是另外用一个索引来存储这个信息。*不确保是这样，kibana4 的代码比 kibana3 难懂多了。*

kibana3 整个界面结构跟 kibana4 不一样，没有单独的字段管理页面，而是通过 `app/services/fields.js` 提供了 `fields.list` 在各个 panel 的 editor.html 里做 `bs-typeahead`。所以，如果完整的思路 port 回来，应该是写一个 *app/services/scriptFields.js* 来提供 scriptedField 的增删改查，然后还要自己写个页面来提供操作界面。

作为页面手残党，我迅速决定放弃这个思路，选择一个更简单的方式来完成类似目的：直接在最常用的 terms panel 里提供输入 script 字符串的功能，反正每个 dashboard 最后会固化成 JSON 的。而且其他 panel 应该不太会用到这个功能(如果要在 table 里也实现，改动又稍大了。Kibana4 里我猜测应该是直接返回勾选的 fields，这个接口是支持 script 的；Kibana3 里则是返回全部字段，然后在 js 里完成的表格字段选择性展示)。

terms panel 中对类似情况就有示例在。这里本是有个 `tmode` 参数，用来选择是用 termsFacet 还是 termstatsFacet API。照葫芦画瓢，我新加了一个 `fmode` 参数，用来选择是普通字段("normal")还是脚本字段("script")：

```html
      <div class="editor-option" ng-show="panel.fmode == 'script'">
        <label class="small">ScriptField</label>
        <input type="text" class="input-large" ng-model="panel.script" ng-change="set_refresh(true)">
      </div>
```

然后在生成 request 的时候，做一下判断：

```javascript
        if($scope.panel.fmode === 'script') {
          terms_facet.scriptField($scope.panel.script)
        }
```

这就 OK 了~

接下来另一个难点：**terms panel 是支持点击生成 filtering 过滤条件的。**

显然 filtering 里没有 script 的支持。filtering 的功能都出自 `app/services/filterSrv.js` 服务。其中 `toEjsObj` 方法调用不同的 Elastic.js 的 Filter 方法。在这里面可以看到原本 terms 的是怎么生成的：

```javascript
      case 'terms':
        return ejs.TermsFilter(filter.field,filter.value);
```

那么我就添加一个：

```javascript
     case 'script':
        return ejs.ScriptFilter(filter.script);
```

filterSrv 支持搞定。最后一步，就是返回 terms panel 的 module.js 里完成调用。过一遍 click 关键字很容易找到 `build_search` 方法。其中原先是这么生成过滤的：

```javascript
      if(_.isUndefined(term.meta)) {
         filterSrv.set({type:'terms',field:$scope.field,value:term.label,
           mandate:(negate ? 'mustNot':'must')});
```

那么在这个前面判断一下：

```javascript
      if($scope.panel.fmode === 'script') {
        filterSrv.set({type:'script',script:$scope.panel.script + ' == \"' + term.label + '\"',
          mandate:(negate ? 'mustNot':'must')});
      } else if(_.isUndefined(term.meta)) {
```

大功告成！

![](http://ww4.sinaimg.cn/large/3dbd9afagw1eo07bw1ygsj20eh0bxjs6.jpg)
