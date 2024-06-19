---
layout: post
theme:
  name: twitter
title: squid的一点小问题
date: 2009-11-17
category: squid
---

网站运行，出错是必然的。squid提供了一整套多国语言的错误信息页面，放在share/errors/目录下。
但是，让人很尴尬的一点是：squid默认的english错误页面中，居然会公开显示客户源站的IP地址。而有一部分客户，用CDN的目的之一就是要用CDN来分担攻击流量，保护自己。这下可好。生生给暴露出去了。
而附带的简体中文页面中，刚好就没这个信息。真不知道是在讽刺国人攻击性太强，心理太黑暗了么……
不管怎么说，得把这个改掉。最简单的办法，修改english页面，删除掉ERR_CONNECT_FAIL里那个关键的信息。关键的就是下面这一段：

Connection to %I Failed

这个%I，就是源站IP。修改成Connection Failed。显示结果就OK了。
这一次成了，难保下一次别的错误信息里又出什么别的问题。干脆的办法，把错误信息定位到中文包上去。
网上办法多多。

最根本的，在源代码编译的时候，就加上--enable-err-language=Simplify_Chinese；

最简单的，删除掉English目录，创建一个同名链接链接到Simplify_Chinese目录上；

最实用的，在squid.conf里加上一句配置语句“error_directory /home/squid/share/errors/Simplify_Chinese”，重启服务，即可。


