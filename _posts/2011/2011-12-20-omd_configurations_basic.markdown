---
layout: post
title: OMD系列(二)基础配置和目录介绍
date: 2011-12-20
category: monitor
tags:
  - nagios
---

话接上篇，在su和omd start之后，可以看到挂载的一个目录。其/omd是/opt/omd的软连接。目录结构如下：

{% highlight bash %}
[monitor@localhost tmp]$ ll /opt/omd/sites/dyxmonitor/
total 12
lrwxrwxrwx  1 monitor dyxmonitor   11 Dec 19 18:15 bin -> version/bin
drwxr-xr-x 21 monitor dyxmonitor 4096 Dec 19 18:15 etc
lrwxrwxrwx  1 monitor dyxmonitor   15 Dec 19 18:15 include -> version/include
lrwxrwxrwx  1 monitor dyxmonitor   11 Dec 19 18:15 lib -> version/lib
drwxr-xr-x  5 monitor dyxmonitor 4096 Dec 19 18:15 local
lrwxrwxrwx  1 monitor dyxmonitor   13 Dec 19 18:15 share -> version/share
drwxr-xr-x 14 monitor dyxmonitor  300 Dec 19 23:32 tmp
drwxr-xr-x 12 monitor dyxmonitor 4096 Dec 19 18:15 var
lrwxrwxrwx  1 monitor dyxmonitor   19 Dec 19 18:15 version -> ../../versions/0.50
{% endhighlight %}

软连接的部分，都是所有omd共用的；tmp就是挂载的tmpfs用来加速数据读写的；var是日志和由前端生成的数据(比如rrd)存放地点；etc是配置文件存放地点，具体内容包括：

{% highlight bash %}
[monitor@localhost etc]$ ls
apache       cron.d       htpasswd  logrotate.conf  mod-gearman  nsca        rc.d            thruk
check_mk     dokuwiki     init.d    logrotate.d     nagios       omd         rrdcached.conf  xinetd.conf
check_multi  environment  jmx4perl  mk-livestatus   nagvis       pnp4nagios  shinken         xinetd.d
{% endhighlight %}

其中，htpasswd定义了auth的用户名密码，默认是omdadmin:omd；
rrdcached.conf定义了rrdcached的过期时间，用来缓解rrdtools的压力；
apache/mode.conf是/opt/omd/apache/monitor.conf里Include的文件，实质是apache/apache-own.conf的软连接；调用了apache/proxy-port.conf来反向代理5000端口的实质页面。
apache/apache.conf是真正的5000端口运行的配置文件，里面Include了apache/conf.d/*.conf——这些conf都是外面不同插件目录里的apache.conf的软连接：

{% highlight bash %}
[monitor@localhost conf.d]$ ll
total 24
-rw-r--r-- 1 monitor monitor 119 Dec 19 18:15 01_python.conf
-rw-r--r-- 1 monitor monitor 482 Dec 19 18:15 02_fcgid.conf
-rw-r--r-- 1 monitor monitor 252 Dec 19 18:15 auth.conf
lrwxrwxrwx 1 monitor monitor  26 Dec 19 18:15 check_mk.conf -> ../../check_mk/apache.conf
lrwxrwxrwx 1 monitor monitor  26 Dec 19 18:15 dokuwiki.conf -> ../../dokuwiki/apache.conf
lrwxrwxrwx 1 monitor monitor  25 Dec 19 23:29 nagios.conf -> ../../shinken/apache.conf
lrwxrwxrwx 1 monitor monitor  24 Dec 19 18:15 nagvis.conf -> ../../nagvis/apache.conf
-rw-r--r-- 1 monitor monitor 519 Dec 19 18:15 omd.conf
lrwxrwxrwx 1 monitor monitor  28 Dec 19 18:15 pnp4nagios.conf -> ../../pnp4nagios/apache.conf
-rw-r--r-- 1 monitor monitor 117 Dec 19 18:15 site.conf
lrwxrwxrwx 1 monitor monitor  23 Dec 19 18:15 thruk.conf -> ../../thruk/apache.conf
-rw-r--r-- 1 monitor monitor 283 Dec 19 18:15 var_www.conf
{% endhighlight %}

另外，在etc下还有omd/site.conf配置文件。这是本site的主配置文件，看起来可能不太清楚，所以omd提供了更直观的修改办法，那就是仿UI的omd config命令：
<img src="/images/uploads/omd.png" alt="" title="omd" width="300" height="173" class="alignnone size-medium wp-image-2830" />
通过这种类似setup的方式直接搞定就可以了。
默认情况下，web页面的首页访问url地址是/monitor/omd/，这个页面上列出了classic nagios、check_mk、nagvis、pnp4nagios和dokuwiki的访问效果截图和地址，可以点击进入查看。然后再用omd config定义Web UI的default选择就是了。一旦定义完成，配置会自动修改，下次再访问/monitor/omd/，就会自动跳转了。
注：/monitor/是因为我create的site名字是monitor
另，修改config后，发现mod_gearman不可用。原因是omd的rpm发布里没有带gearmand的实现，必须自己另外搞定gearman的jobserver~~
