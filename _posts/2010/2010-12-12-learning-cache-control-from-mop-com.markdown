---
layout: post
title: 从猫扑论坛看终极页的缓存控制
date: 2010-12-12
category: CDN
---

GF找我要猫扑账号，只好去申请了一个，顺带着之前分析天涯的劲头，把猫扑也看看~

猫扑的左右分栏与天涯等论坛都不同，其左侧栏提供了大量推荐文章和栏目列表，右侧栏作为具体内容的阅读使用，通过firebug和源码阅读可以看到，左侧栏是通过frame加载的 `/leftFrame.jsp?type=*` ，再由该jsp根据后面的参数来调用相应的html页；右侧栏是通过js中定义的 `openRightUrl` 来打开具体某个html帖子，这个 `openRightUrl` 定义在<http://txt.mop.com/dzhjs/dzh2js/turlUrl.js?version>里，其实就是一个 `right.location.href`。显然这个js将成为上猫扑时最常用的文件，其缓存时间相当长~header中可以看到 `Cache-Control: max-age=8640000` 

另，虽然header中的Server内容被修改，但当不带参数访问 `/leftFrame.jsp` 时，其调用的 `*_0_0.html` 不存在，显示出了 nginx0.7.34 的 404 错误页面。但随意输入 abcd.html，却能返回猫扑自定的错误页面，这也是比较怪的一点，怀疑其 nginx 的 proxy 配置不太正确。

最后还是看html的缓存控制和回复时的控制。

从列表中复制具体一个帖子的html链接地址另行打开，比如 `http://dzh.mop.com/topic/readSub_12990049_0_0.html` 第一个数应该是帖子号，第二个数是页码（从0开始计数~），第三个未知……

可以看到这该域名下的html的默认配置，max-age是180。

然后写下评论，点击提交回复。内容随即更新了，但url抓起到的url却是 `http://dzh.mop.com/topic/readSub_12990049_-1_0.html` ，而这个url的max-age设定是0！
比较奇怪的是，回复时POST提交的url并没有和天涯一样返回一个302指向，而是返回一个无内容的200，但页码依然跳转了，而且 `-1_0.html` 的refer也不是POST的jsp，而是原先停留的 `0_0.html` ……

另外点了一下全文观看，其页码是-2，max-age也是180，显然回复后的显示url是特意定制的header~~

最后，有图有真相：

![mop](/mop.jpg)
