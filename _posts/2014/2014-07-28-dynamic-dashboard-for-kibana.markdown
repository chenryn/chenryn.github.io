---
layout: post
title: "Kibana 动态仪表板的使用"
category: logstash
tags:
  - kibana
---

半年前，Kibana3.4 版刚出来的时候，曾经在官方博客上描述了一个新功能，当时我的翻译见：[【翻译】Kibana3 里程碑 4](/2014/01/15/kibana3-milestone4-20131105/)。

今天我实际使用了一下这个新功能，感觉还是蛮有用的，单独拿出来记录一下用法和一些没在之前文章里提到的细节。

## 使用方法

使用方法其实在官方描述里已经比较清楚了。就是在原本的 `http://127.0.0.1:9292/#/dashboard/file/logstash.json` 地址后面，再加上请求参数 `?query=***` 即可。

## 注意事项

看起来好像太过简单，不过用起来其实还是有点注意事项的：

* Kibana 目前不支持对保存在 Elasticsearch 中的 dashboard 做这个事情。

所以一定得保存成 `yourname.json` 文件放入 `app/dashboards/` 目录里才行。

* 静态的 JSON 文件其实是利用模板技术。

所以直接导出得到的 JSON 文件还不能直接起作用。需要稍微做一点修改。

你可以打开默认可用的 `logstash.json` 文件，看看有什么奇特的地方，没错，就是下面这样：

    "query": "\{\{ARGS.query || '*'\}\}"

而你自己保存下来的 JSON，这里都会是具体的数据。所以，要让自己的 JSON 布局也支持动态仪表板的话，按照这个写法也都加上 `ARGS.query` 就好了！

从 logstash.json 里还可以看到，除了 `?query=` 以外，其实还支持 `from=` 参数，默认是 `24h`。

* query 参数的特殊字符问题。

比如我之前在搜索框里输入的 querystring 是这样的：`type:mweibo_action AND urlpath:"/2/statuses/friends_timeline.json"` 。

那么实际用的时候，如果写成这样一个 url：`http://127.0.0.1:9292/#/dashboard/file/logstash.json?query=type:mweibo_action AND urlpath:"/2/statuses/friends_timeline.json"`，实际是不对的。我一度怀疑是不是 urlpath 里的 `/` 导致的问题，后来发现，其实是 `"` 在进 JSON 文件模板变量替换的时候给当做只是字符串赋值引号的作用，就不再作为字符串本身传递给 Elasticsearch 作为请求内容本身了。**所以需要用 `\` 给 `"` 做转义。**

(这里一定要有 `"` 的原因是，ES 的 querystring 里，`field:/regex/` 是正则匹配搜索的语法，刚好 url 也是以 `/` 开头的)

所以可用的 url 应该是：`http://127.0.0.1:9292/#/dashboard/file/logstash.json?query=type:mweibo_action AND urlpath:\"/2/statuses/friends_timeline.json\"`！

经过 url_encode 之后就变成了：`http://127.0.0.1:9292/#/dashboard/file/logstash.json?query=type:mweibo_action%20AND%20urlpath:%5C%22%2F2%2Fstatuses%2Ffriends_timeline.json%5C%22`

这样就可以了！

* 用 JSON 的局限。

动态仪表板其实有两种用法，这里只用到了 `file/logstash.json` 静态文件方式，这种方式只支持一个 query 条件，也没有太多的附加参数支持。而 `script/logstash.js` 方式，支持多个 query 条件，以及 index、pattern、interval、timefield 等更多的参数选项。

当然，研究一下 angularjs 的用法，给 JSON 文件里也加上 `ARGS.query` 的 `split` 方法，也不算太难。
