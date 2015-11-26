---
layout: post
title: 用 phantomjs 截图
tags:
  - javascript
  - kibana
---

昨儿给 kibana 加上了 table 面板数据导出成 CSV 的功能。朋友们就问了，那其他面板的图表怎么导出保存呢？其实直接截图就好了嘛……

FireFox 有插件用来截全网页图。不过如果作为定期的工作，这么搞还是比较麻烦的，需要脚本化下来。这时候就可以用上 phantomjs 软件了。phantomjs 是一个基于 webkit 引擎做的 js 脚本库。可以通过 js 程序操作 webkit 浏览器引擎，实现各种浏览器功能。

因为用了 webkit ，所以软件编译起来挺麻烦的，建议是直接从官方下载二进制包用得了。

想要给 kibana 页面截图，几行代码就够了：

```javascript
var page = require('webpage').create();
var address = 'http://kibana.dip.sina.com.cn/#/dashboard/elasticsearch/h5_view';
var output = 'kibana.png';
page.viewportSize = { width: 1366, height: 600 };
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address!');
        phantom.exit();
    } else {
        window.setTimeout(function () {
            page.render(output);
            phantom.exit();
        }, 20000);
    }
});
```

这里两个要点：

1. 要设置 `viewportSize` 里的宽度，否则效果会变成单个 panel 依次往下排列。
3. 要设置 `setTimeout`，否则在获取完 index.html 后就直接返回了，只能看到一个大白板。用 phantomjs 截取 angularjs 这类单页 MVC 框架应用时一定要设置这个。

