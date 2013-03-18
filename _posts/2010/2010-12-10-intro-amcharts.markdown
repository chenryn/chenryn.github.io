---
layout: post
title: flash绘图利器-amcharts
date: 2010-12-10
category: web
tags:
  - amcharts
---

作为SA最常用的绘图工具肯定是rrdtool；而coder最常用的肯定是gd；前段时间从ibm文库里学到一个同样很强大的函数绘图工具gnuplot；最近在技术群里又见识到一些更新奇小巧的绘图工具，记录一下~

google的API提供一个简易而不失美观的方法（详见<http://code.google.com/intl/zh-CN/apis/charttools/docs/choosing.html>）只需要在url的strings里提供一些数据，google就能直接返回给你想要的图表。当然也能采用google提供的js库完成高级一些的内容——不过对某些小心翼翼的SA来说，采用外部js总让人有一种不安全感~而比较固定的样式又可能不足以让销售部门的同事满意……

扶凯大大及时冒泡，提供给大家另一个工具：amcharts！一个flash绘图工具。flash的美观度和互动能力绝对是众所周知的有保证~（详见<http://www.amcharts.com/>）官网界面简洁明快，各种examples，包括股价图、柱状图、饼状图、线面图、散点图，网状图，支持3D效果、渐变效果、背景图自定义、指针自定义图文提示、数据动态输入等各种功能。xml配置文件的每个标签都有详细注释。使用时，只需要在webroot下放上amcharts的swf，写好settings.xml，在html里插入swf即可~

在选择到stock的Smoothed line chart(平滑线图)时，我很惊讶的发现：这不就是之前我一直很赞叹的蓝汛客户服务平台里的带宽flash图么？如下所示：

![amcharts](/images/uploads/charts.jpg)

不过这个工具虽然千好万好，没想出来对我目前的工作有啥使用的必要……姑且记录之~

