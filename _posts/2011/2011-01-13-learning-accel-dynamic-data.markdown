---
layout: post
theme:
  name: twitter
title: 读《基于动态内容的缓存加速技术》笔记
date: 2011-01-13
category: CDN
---

《程序员》2010年11月刊的86-89四页，刊登了F5售前技术顾问，原VIACDN(TOM的CDN部门，后来独立运营)架构师徐超的文章《基于动态内容的缓存加速技术——F5 Web Accelerator产品技术剖析》。

文章的前三分之一内容，主要是讲述RFC2616和一般浏览器、服务器的具体实现。已经比较熟悉了，略过……

然后进入关键内容。

“让浏览器缓存能够为动态页面工作”：
A. 修改Transfer-Encoding: chunked的内容输出Content-Length。
这个squid已经做到了。其实质就是在获取url的body时，累加每个chunk的size，直到碰上MSB为0的last-chunk标记。
B. 添加Last-Modified。
这个squid差一步。squid实质已经获取了文件在本地的mtime，但只在源header不存在last-modified的时候才用于LM-factor算法。
C. 删除Expires。
大概是为了统一成HTTP/1.1的header，所以选择了删除expires？或者就是纯粹了节省代码吧……
D. 修改Cache-Control。有Expires按这个设定max-age，或者按配置设定；有private的修改成public；添加must-revalidated。
这个squid用header_access和header_replace就能完成。

“Web Accelerator如何识别动态页面的更新并保持更新”：
A. 预加载。
这个通过squid的补丁html prefetching可以完成
B. 根据上一章节的修改结果，浏览器对"动态html"每次都可以发送IMS到F5。F5向源站请求该html，并比对缓存内容。
其他过程和一般的IMS过程一样，关键在比对缓存内容。如果这个"动态"只是html文字内容的更新，还是正常范围；如果"动态交互"的结果还包括其他CSS/JS/JPG/GIF的变动，这个功能就比较有用了。
根据预加载的功能，每次确认html时重新预比对。考虑到CSS/JS/JPG/GIF一般来说都是会输出Last-Modified的，这个比对返回结果应该比较快。都没问题的话，跳过这步；
如果有部分文件mtime也变动了，开始预加载，并另存为一个带有版本号的url(比如logo.gif;pv=***)，用','而不能用'?'，因为?在浏览器上是不缓存的；
同时修改主文件html的内容，替换url链接为新版本号的url。最后发送这个新版本html给浏览器。
这种版本号控制的方法也节省了缓存更新时的删除操作IO，而统一交给LRU之类的完成。
想到LRU，一个疑问：当缓存不足时，假如logo.gif已经被prune出去了，那这个时候的F5怎么办？几个猜测办法：
1、浪费一点带宽和时间，以新版本号url的形式重新进入缓存；
2、用一个版本号/mtime的K-V数据库完成url版本控制；
3、F5作为特定类型给某些网站使用，就不考虑海量文件的问题。
最后，我还是觉得url版本控制这种事情，还是由网站开发人员来做CMS比较靠谱。

“反向动态代理”
上面的方式，确实保证了数据"实时"性，而且充分利用了浏览器缓存，但一次刷新引发F5和源站之间几十上百次的比对，还是比较郁闷的。所以当网站的"动态"结构比较清晰时，比如一个论坛，明确知道帖子列表变动就是因为有人发帖了；而且可以从发帖的POST请求url里推导出版面url的，可以采用这种技术。
一旦接收到POST请求，F5自动根据配置purge版面url的缓存。而不用去比对。

“MultiConnect技术”
因为浏览器对同一域名并发连接很少，所以F5可以自动替换html里的url，根据配置把image.x.com换成img1.x.com/img2.x.com/img3.x.com……前提是你的DNS上确实有这些解析。
不过要注意，域名太多也会拖慢浏览器速度的。dns解析需要时间。

总之，个人感觉这些技术还是比较现实的，但都用很强的应用场景针对性。呵呵~
