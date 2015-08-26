---
layout: post
title: 【翻译】Kibana 字段的自定义展示格式开发
category: logstash
tags:
  - kibana
---

原文地址：<http://www.elasticsearch.org/blog/kibana-custom-field-formatters>

Kibana 4.1 引入了一个新特性叫字段展示格式(field formatters)，让我们可以实时转换字段内容成更形象的样式。这个特性帮助我们不修改数据的存储方式，而用另一种方式显示它。有关 field formatters 的介绍，可以阅读之前一篇[博客](https://www.elastic.co/blog/kibana-4-1-field-formatters)。

本文的目的，则是带大家过一遍 field formatters 的开发流程。从 field formatter 接口开始，自己实现一个基础的 formatter，可以字段给 error 单词加高亮效果，最后完成整个解决方案。

## 起步

Kibana 开发环境的搭建介绍可以在 [Kibana repository](https://github.com/elastic/kibana/blob/master/CONTRIBUTING.md#development-environment-setup) 看到。

从 Kibana 根目录触发，field formatters 相关代码存在 `/src/ui/public/stringify` 目录下。目录结构如下所示：

> /stringify
> |--type  //包括各种 formatter
> |--icons
> |--editors  //formatter 用来请求和显示附加信息的 HTML 页面
> |--__tests__
> |--register.js //每个 formatter 都要在这里面注册

Kibana 4.1 里，formatters 位置则在 `/src/kibana/components/stringify`。如果你是看的 4.1 版，可能跟本文讲的路径稍有区别，请自动对应查找一下，本文以 git master 为准。

现在，让我们在 `type` 目录 下创建一个文件叫 `Highlight.js`，下面是初始代码：

{% highlight js %}
define(function (require) {
  return function HighlightFormatProvider(Private) {
    var _ = require('lodash');
    var FieldFormat = Private(require('ui/index_patterns/_field_format/FieldFormat'));
    _.class(Highlight).inherits(FieldFormat);
    function Highlight(params) {
      Highlight.Super.call(this, params);
    }
    Highlight.id = 'highlight';
    Highlight.title = 'Highlight';
    Highlight.fieldType = ['string'];
    Highlight.prototype._convert = {
      text: _.escape,
      html: _.escape
    };
    return Highlight;
  };
});
{% endhighlight %}

每种字段格式，都实现为扩展 FieldFormat 的类。`Highlight.id` 用在 Kibana 内部跟踪 formatter，每个 formatter 必须采用不同的 id。`Highlight.title` 显示在 formatter 下拉选择框里，`Highlight.fieldType` 则描述自己适用于哪种类型的字段内容。

`Highlight.prototype._convert` 是实际进行格式化的地方。包括有 text 和 html 两种方法。text 方法用于 tooltips, filters, legends, 和 axis markers。html 方法用于搜索表格内。两者都接收字段内容为输入，输出我们希望的展示内容。如果两个方法是一样的，可以直接赋值 `Highlight.prototype._convert` 为一个函数。给 error 单词加高亮的代码如下：

{% highlight js %}
Highlight.prototype._highlight = function (val, replace) {
  return _.escape(val).replace(/(error)/g, replace);
};
Highlight.prototype._convert = {
  text: function(val) {
    return this._highlight(val, function convertToUpperCase(match) {
      return match.toUpperCase();
    });
  },
  html: function(val) {
    return this._highlight(val, '<mark>$&</mark>');
  }
};
{% endhighlight %}

只要字段内容中有 error 文本字样，我们就会根据 HTML 或者 text 场景选择包含进 mark 元素或者是转换成大写形式。注意这里使用的 `_.escape(val)` 语句，这句可以用来放置 HTML 注入和跨站脚本攻击。

然后需要注册这个新的 field formatter。在 register.js 里添加：

{% highlight js %}
fieldFormats.register(require('ui/stringify/types/Highlight'));
{% endhighlight %}

未来，我们(Kibana 开发组)可能会把这个功能以插件形式提供，届时注册方法会更加简单。

现在我们可以对 string 类型的字段选择 Highlight 作为 field formatter 了！

![](https://www.elastic.co/assets/blt3b40cdcf8a606803/select.png)

在 Discover 页测试效果：

![](https://www.elastic.co/assets/bltbd8a84ea59294648/highlight-error.png)

## 更通用化

插件已经可以运行了，但是我们如果想更通用化一点，不单单可以用来高亮 error 字眼呢？当然不用给每个单词开发一种 formatter，我们可以提供一个输入正则表达式的方式。

在 editor 目录，添加一个叫 `highlight.html` 的文件，内容如下：

{% highlight js %}
<div class="form-group">
  <label>Pattern</label>
  <input class="form-control" ng-model="editor.formatParams.pattern"/>
</div>
{% endhighlight %}

然后回到 Highlight.js 里，我们需要定义 `highlight.html` 作为我们的编辑页面，然后更新我们的 `_highlight` 方法，使用输入文本作为匹配时的正则表达式。

{% highlight js %}
Highlight.editor = require('ui/stringify/editors/highlight.html');
Highlight.prototype._highlight = function (val, replace) {
  var escapedVal = _.escape(val);
  var highlightPattern;
  try {
    var inputRegex = this.param('pattern').split('/');
    var pattern = inputRegex[0] || inputRegex[1];
    var flags = inputRegex[2];
    highlightPattern = new RegExp(pattern, flags);
  } catch(e) {
    return escapedVal;
  }
  return escapedVal.replace(highlightPattern, replace);
};
{% endhighlight %}

## 示例

如果在应用 formatter 之前，就能看到输入的正则表达式的效果就更好了。Kibana 里提供了一个 directive 指令让我们可以在修改表达式时观察示例变化。

我们可以增加一些输入字段，并且在模板中加入这个指令。也就是在 highlight.html 后面追加下面这段：

{% highlight js %}
<field-format-editor-samples inputs="editor.field.format.type.sampleInputs"></field-format-editor-samples>
{% endhighlight %}

对应的，在 Highlight.js 里添加下面这段:

{% highlight js %}
Highlight.sampleInputs = [
  'Hello world',
  'The quick brown fox jumps over the lazy dog',
  '112345'
];
{% endhighlight %}

最终结果如下：

![](https://www.elastic.co/assets/blt8bbd181d804191a0/sample.png)

## 结论

field formatter 接口提供了非常简便的办法让我们定制字段内容的展示方式。Kibana 自带了好几种 formatter，不过如果你没发现比较合适的，你可以随时自己开发添加一个。如果你已经开始计划添加了，也请注意在 Kibana 4.2 发版的时候，回来看看，有没有新的接口变更。
