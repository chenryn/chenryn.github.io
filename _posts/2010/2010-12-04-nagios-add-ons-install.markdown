---
layout: post
title: nagios的add-ons安装小抄~
date: 2010-12-04
category: monitor
tags:
  - nagios
---

给nagios安装几个add-ons，碰到一些一般安装教程上不会提及的问题，记录一下：

1、ndoutils：
在./configure通过后make一直error，因为不管是否--with-mysql-lib，也不管--with-mysql-lib=/usr/local/mysql/lib还是/usr/local/mysql/lib/mysql，甚至使用LDFLAGS=-I/usr/local/mysql/lib等等，最后在make的时候总还是会报出如下错误：
../include/config.h:261:25: error: mysql/mysql.h: No such file or  directory
../include/config.h:262:26: error: mysql/errmsg.h: No such file or  directory
解决办法：编辑config.h文件的261和262行，把mysql/*.h的mysql/删除掉即可。

make完成后，将相应文件cp到指定目录，启动ndomod会报错libmysqlclient.so.6.0.0动态链接库无法找到。网上一般都说ln -s /usr/local/mysql/lib/* /usr/lib;echo '/usr/lib' >> /etc/ld.so.conf;ldconfig即可。其实还不行。
解决办法：echo '/usr/local/mysql/lib/mysql' > /etc/ld.so.conf.d/mysql.conf;ldconfig即可。因为通用办法的目录不够深。

2、pnp4nagios：
之前使用的pnp0.4.*版本，今天下的是pnp0.6.*版本。整个url设计发生了较大变化。各监控项页面的url从pnp4nagios/index.php?host=&amp;service=变成了/pnp4nagios/graph?host=&amp;service=。而这个graph（rrd图像的url是/pnp4nagios/image?***）则通过apache的mod_rewrite实现。
pnp自己编译时可以make出来一个httpd.conf。其中相关Rewrite的包括：
{% highlight apache %}
<Directory '"/usr/local/pnp4nagios/share/">
RewriteEngine On
RewriteBase /pnp4nagios/
RewriteRule ^(application|modules|system) - [F,L]
RewriteCond %{REQUEST_FILENAME} !-d
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule .* index.php$0 [PT,L]
</Directory>
{% endhighlight %}
因为pnp编译时没有具体区分etc和share的路径，所以之后apache的发布路径也不同，为了方便，不再写directory。最后经过反复试验，可用配置如下：
{% highlight apache %}
RewriteEngine On
RewriteRule ^(application|modules|system) - [F,L]
RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-d
RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-f
RewriteRule ^/nagios/pnp4nagios/(.*) /nagios/pnp4nagios/index.php$1 [PT,L]
{% endhighlight %}

试验中发现几个apache与nginx的不同：
1、rewriterule的转向url不能用^标记起始端！
2、PT的强制进入下一个处理器相当有用，不然会形成回环rewrite！
3、rewritecond里德%{REQUEST_FILENAME}默认是在rewritebase下的——而rewritebase只能在directory里使用。
