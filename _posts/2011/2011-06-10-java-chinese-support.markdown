---
title: java的中文支持
layout: post
date: 2011-06-10
category: linux
---

往论坛上传图片，有的图片上有中文字，却显示成方框。求助了一下度娘，快速解决。记录一下：
* 第一步，在windows下找到simsun.ttc文件，嗯，ntfs系统下强力推荐everything小工具一个；
* 第二步，上传simsun.ttc到服务器的/usr/share/fonts/zh_CN/下，其他路径也行，不过这个路径比较通用；
* 第三步，在$JAVA_HOME/jrp/lib/下创建fontconfig.properties.zh文件，原型格式可见同目录下的fontconfig.properties.src。
fontconfig.properties.zh文件相关内容如下：
{% highlight java %}
allfonts.chinese-gbk=-misc-simsun-medium-r-normal--*-%d-*-*-p-*-gbk-0
allfonts.chinese-gb2312=-misc-simsun-medium-r-normal--*-%d-*-*-p-*-gb2312.1980-0
sequence.allfonts.GB18030=latin-1,chinese-gbk,chinese-cn-iso10646
sequence.allfonts.GBK=latin-1,chinese-gbk
sequence.allfonts.GB2312=latin-1,chinese-gb2312
sequence.allfonts.UTF-8.ko.KR=latin-1,korean,japanese-x0208,japanese-x0201,chinese-gbk
sequence.allfonts.UTF-8.ja.JP=latin-1,japanese-x0208,japanese-x0201,chinese-gbk,korean
sequence.fallback=lucida,chinese-big5,chinese-gbk,japanese-x0208,korean
filename.-misc-simsun-medium-r-normal--*-%d-*-*-p-*-gbk-0=/usr/share/fonts/zh_CN/simsun.ttc
filename.-misc-simsun-medium-r-normal--*-%d-*-*-p-*-gb2312.1980-0=/usr/share/fonts/zh_CN/simsun.ttc
awtfontpath.chinese-gb2312=/usr/share/fonts/zh_CN
awtfontpath.chinese-gbk=/usr/share/fonts/zh_CN
{% endhighlight %}
很简单的一件小事儿，一来作个记录，二来测试微博同步——从百度统计看我可怜的一点点访问都来自微博……
