---
layout: post
title: 页面自动刷新小问题
date: 2010-10-21
category: monitor
tags:
  - cacti
---

cacti的页面，每5分钟自动刷新一次，这样就可以“实时”的看到rrd绘图的最新结果。

nagios加上pnp插件后，也有rrd绘图的页面，但却没有自动刷新。

查看pnp/config.cfg，里面已经配置了$conf['refresh'] = "90";但页面没有反应。

于是分别查看cacti和pnp的页面源代码，cacti的如下：

<meta http-equiv=refresh content='300'>

pnp的如下：

<meta http-equiv="refresh" content="90; URL=***">

看来时这个META标签写法不对，修改nagios/share/pnp/include/funcation.inc.php如下：

- print "<meta http-equiv=\"refresh\" content=\"" . $conf['refresh'] . "; URL=" . $_SERVER['REQUEST_URI'] . "\">\n";

+ print "<meta http-equiv=\"refresh\" content=\"".$conf['refresh']."\">\n";

保存退出，刷新页面后等待90s，果然更新了~~
