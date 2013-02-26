---
layout: post
title: 客户页面小故障
date: 2010-04-10
category: CDN
tags:
  - html
---

今天接到客户电话，说，主页已经提交过了刷新任务，上面的图片已经更新，但点击图片后链接到的页面内容还是老的……
仔细一看，原来主页里的html是这么定义的：
{% highlight html %}
<a href="http://msn.golfbox.cn/cache/922/36717.html" target="_blank"><img src="/upload/img/20100410/20100410144202.jpg" width="125" height="80" class="border_blue" /></a>
{% endhighlight %}
而http://msn.golfbox.cn/cache/922/36717.html的内容是这样：
{% highlight html %}
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" /><script language="JavaScript">
 location.replace("http://msn.golfbox.cn/cache/874/36804.html");
</script>
{% endhighlight %}
于是跟客户交流确认，他们网站的主页框架上比较固定的地方，都是采用这种方式，来提供内容更新的。。。
他们又不肯给出具体更新了那些跳转页面，只好写个小脚本，去处理比对。如果有相同url的location.replace地址不统一的，就强制更新这些页面。
{% highlight bash %}
#!/bin/bash
curl http://msn.golfbox.cn/ |sed 's/\n//g'|sed 's/href=/\n/g'|grep "^"http://msn.golfbox.cn/cache"|awk -F'"' '{print $2}'>url
for j in `cat url`;do
 for i in `cat ip`;do
  curl -x $i:80 $j|awk -F'"' '/replace/{print "'$j'","'$i'",$2}'>>golfbox.log
#  curl -x $i:80 -I $j|awk '/Age/{print "'$j'","'$i'",$2}'>>age.log
 done
done
cat golfbox.log |awk '{if($1==a){if($3!=b){system("/home/squid/bin/squidclient -p 80 -h "$2" -m purge "$1)}};a=$1;b=$3}'
{% endhighlight %}
（该脚本有一个问题：如果刚好是第一台的url未更新，结果会反而去刷新那些已经更新了的服务器；所以应该是输出url，然后再用for do done去刷新所有服务器~如果curl可以在获取内容的同时获取Age就好了~所以最后用一个讨巧的办法：在ip列表的最开始放上客户源站的ip，这样就能保证最新了）
以上是第一个。
第二个：
客户首页上还有一个问题：其右下角有跟随悬浮窗口，本来应该可以关闭的。但一点关闭，就提示javascrpt:iclose()错误页面。而用浏览器另存为html到桌面以后，再打开保存下来的页面，点击关闭就正常关闭了！
经过查找，其中调用的js文件是http://msn.golfbox.cn/js/show.js，内容中关于javascrpt:iclose()的内容如下：
{% highlight javascript %}
var sogouTall ='<div style="z-index:1000;position: absolute;display:none;" id="sogoubox">'
   +'<a href="javascript:iclose();" style="float:left; margin-left:190px">关闭</a>'
   +'<div style="clear:both">'
   +'<a href="<a href="http://new.msn.golfbox.cn/wd/">http://new.msn.golfbox.cn/wd/"><img</a> src="<a href="http://new.msn.golfbox.cn/wd/dbtt.jpg">http://new.msn.golfbox.cn/wd/dbtt.jpg</a>" style="width:220px;height:160px"/></a>'
      + '<input type=hidden name="sogouAccountId" value="202014">'
   + ''
 function iclose()
 {
  document.getElementById('sogoubox').style.display='none';
 }
{% endhighlight %}
以我浅薄的web知识，是没看出来什么问题~~客户也莫名其妙，最好撤销掉这个窗口了
