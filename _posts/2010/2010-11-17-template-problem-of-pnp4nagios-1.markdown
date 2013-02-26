---
layout: post
title: pnp4nagios的模板问题(1)
date: 2010-11-17
category: monitor
tags:
  - nagios
  - rrdtools
  - php
---

实在是看不下去pnp4nagios的丑陋的rrd效果，想着自己修改一下模板。

很容易找到了目前使用的模板：nagios/share/pnp/templates.dist/default.php，不过看到目录下已经有不少其他的模板文件，为啥一个都没用上呢？

从nagios/share/pnp/include/function.inc.php里看到了doFindTemplate()，定义如下：
{% highlight php %}
if (is_readable($conf['template_dir'].'/templates/' . $template . '.php')) {
$template_file = $conf['template_dir'].'/templates/' . $template . '.php';
}elseif (is_readable($conf['template_dir'].'/templates.dist/' . $template . '.php')) {
$template_file = $conf['template_dir'].'/templates.dist/' . $template . '.php';
}elseif (is_readable($conf['template_dir'].'/templates/default.php')) {
$template_file = $conf['template_dir'].'/templates/default.php';
}else {
$template_file = $conf['template_dir'].'/templates.dist/default.php';
}
{% endhighlight %}
也就是说其实pnp是找不到对应check_command的模板，才使用了最后的default.php！

正巧，default.php里输出了check_command到rra上，可以看到，几乎所有的命令输出都是"Check Command check_nrpe"。

也就是说，pnp设计者很贴心的设计了自动查找命令模板的功能，却没有考虑到nagios最广泛的应用插件nrpe……

在pnp官网文档<a href="http://docs.pnp4nagios.org/pnp-0.4/tpl?s[]=template">http://docs.pnp4nagios.org/pnp-0.4/tpl?s[]=template</a>上指出，rrd使用模板是读取了perfdata中相应的xml文件，xml内容类似如下几行：
{% highlight xml %}
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<NAGIOS>
<DATASOURCE>
<TEMPLATE>check_nrpe</TEMPLATE>
<IS_MULTI>0</IS_MULTI>
<DS>1</DS>
<NAME>eth0_in</NAME>
<UNIT>Mbps</UNIT>
<ACT>2.96</ACT>
<WARN>976.56</WARN>
<WARN_MIN></WARN_MIN>
<WARN_MAX></WARN_MAX>
<WARN_RANGE_TYPE></WARN_RANGE_TYPE>
<CRIT>976.56</CRIT>
<CRIT_MIN></CRIT_MIN>
<CRIT_MAX></CRIT_MAX>
<CRIT_RANGE_TYPE></CRIT_RANGE_TYPE>
<MIN>0</MIN>
<MAX>0</MAX>
</DATASOURCE>
{% endhighlight %}
这些标签都是给模板使用的，比如default.php中输出命令的那行就是：
$def[$i] .= 'COMMENT:"Check Command ' . $TEMPLATE[$i] . '\r" ';

如果直接修改xml中的<TEMPLATE>标签内容，确实可以调用成新的模板显示。但间隔时间一过，xml就自动更新成默认配置输出的结果……

解决在大规模环境下nrpe监控数据绘图模板的问题~或许还得继续查找xml的定义，待续ing~

补充：看到官网如下网页，似乎是针对这个问题的，英文慢慢啃~
<a href="http://docs.pnp4nagios.org/pnp-0.4/tpl_custom">http://docs.pnp4nagios.org/pnp-0.4/tpl_custom</a>
