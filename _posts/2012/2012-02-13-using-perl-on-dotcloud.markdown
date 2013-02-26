---
layout: post
title: dotcloud试用
category: cloud
tags:
  - perl
---


dotcloud是日本的一个PAAS厂商。一年多前因为plack作者的加入推出了对perl的支持。我这几个月没事做，今天想起来试试看。用起来确实蛮舒服的。（注：大部分内容是网上已经有了的，我这只是记录一下自己的步骤）
## 第一步，申请账号

就跟普通的网站注册一样，填用户名密码邮箱，邮箱邮件激活——完毕。

## 第二步，安装客户端

跟安装其他python模块一样：

{% highlight python %}
easy_install pip && pip install dotcloud
{% endhighlight %}

## 第三步，个人密钥认证

在dotcloud的个人主页( "settings":http://www.dotcloud.com/account/settings )上就能看到个人密钥。然后在终端里输入密钥：

{% highlight bash %}
[root@localhost ~]# dotcloud
Enter your api key:
{% endhighlight %}

这个密钥就存在了~/.dotcloud/dotcloud.conf里，以后就不用再认证了。

## 第四步，创建项目文件

{% highlight bash %}
[root@localhost ~]# mkdir myapp-on-dotcloud && cd myapp-on-dotcloud
[root@localhost myapp-on-dotcloud]# dotcloud create myapp-on-dotcloud
[root@localhost myapp-on-dotcloud]# dancer -a helloworld
[root@localhost myapp-on-dotcloud]# touch dotcloud.yml
[root@localhost myapp-on-dotcloud]# echo "require 'bin/app.pl';" > helloworld/app.psgi
{% endhighlight %}

用dotcloud命令创建项目myapp-on-dotcloud，并且在项目中运用dancer。唯一需要多加一个文件app.psgi，这个文件是云环境中psgi运行时需要读取的。

## 修改云环境配置

* dotcloud.yml的配置，这相当于云环境的Basic File:

{% highlight yaml %}
www:
  type: perl
  approot: helloworld
  requirements:
    - Template::Toolkit
    - JSON
db:
  type: mysql
{% endhighlight %}
这个yaml文件，第一级是节点的名字，可以随意取名，主要的是type，必须是dotcloud支持的，比如静态文件的static，动态应用的perl，数据库的mysql等等。然后是approot，指定web应用的/路径。最后是requirements，不过这个也可以通过Makefile.PL文件来指明。

* Makefile.PL的修改:

{% highlight perl %}
use strict;
use warnings;
use ExtUtils::MakeMaker;
 
WriteMakefile(
    NAME                => 'helloworld',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/helloworld.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3080,
        'Plack'      => 0.9985,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'helloworld-*' },
);
{% endhighlight %}

这个文件绝大多数是dancer命令自动创建的。唯一需要补充的一行是Plack。因为dotcloud不能自动根据dancer安装plack环境。

## 第六步，上传项目，等待环境部署

{% highlight bash %}
[root@localhost myapp-on-dotcloud]# dotcloud push myapp-on-dotcloud
{% endhighlight %}

然后可以看到程序首先是启动rsync命令，根据UNIX时间戳比对文件变化。上传新文件后，会根据最新的Makefile的配置安装相应的模块。最后初始化项目，创建相应的请求路由。

## 第七步，检查环境数据

运行dotcloud info myapp-on-dotcloud命令，即可看到如下输出：

{% highlight yaml %}
db:
    config:
        mysql_masterslave: true
        mysql_password: A1BAAaAaaaA5Aa1aAAAa
    instances: 1
    type: mysql
www:
    config:
        path: /
        plack_env: deployment
        static: static
        uwsgi_processes: 4
    instances: 1
    type: perl
    url: http://myapp-on-dotcloud-user.dotcloud.com/
{% endhighlight %}

于是我们就可以看到数据库的密码了。然后我们可以这样运用dotcloud的数据库：

{% highlight bash %}
[root@localhost helloworld]# dotcloud run myapp-on-dotcloud.db -- mysql -uroot -pA1BAAaAaaaA5Aa1aAAAa
# mysql -uroot -pA1BAAaAaaaA5Aa1aAAAa
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 34
Server version: 5.1.41-3ubuntu12.10-log (Ubuntu)
 
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
 
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
+--------------------+
2 rows in set (0.00 sec)
 
mysql> Bye
{% endhighlight %}

可以看到，创建出来的mysql节点，是带有replica功能的，而且默认没有创建项目同名的库，需要自己创建。
类似的，也可以通过ssh管理项目节点。详细的查看命令是dotcloud info raocl.www（看起来很面向对象化吧）：

{% highlight yaml %}
aliases:
- myapp-on-dotcloud-user.dotcloud.com
build_revision: rsync-1329106583210
config:
    path: /
    plack_env: deployment
    static: static
    uwsgi_processes: 4
created_at: 1329103902.969918
datacenter: Amazon-us-east-1a
image_version: 87ce0731fd95 (latest)
ports:
-   name: ssh
    url: ssh://dotcloud@myapp-on-dotcloud-user.dotcloud.com:7478
-   name: http
    url: http://myapp-on-dotcloud-user.dotcloud.com/
state: running
type: perl
{% endhighlight %}

这里可以清楚的看到节点是运行在amazon的EC2上的，开起来7478端口的ssh可用。当然没必要自己用ssh去链接，因为可以这样直接运行：

{% highlight bash %}
[root@localhost helloworld]# dotcloud ssh myapp-on-dotcloud.www
# $SHELL
dotcloud@myapp-on-dotcloud-default-www-0:~$ id
uid=1000(dotcloud) gid=33(www-data) groups=33(www-data)
dotcloud@myapp-on-dotcloud-default-www-0:~$ w
 06:36:34 up 62 days, 21:20,  1 user,  load average: 1.26, 1.52, 2.07
USER     TTY      FROM              LOGIN@   IDLE   JCPU   PCPU WHAT
dotcloud@myapp-on-dotcloud-default-www-0:~$ ps auxwwf
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
dotcloud   189  0.0  0.0  70632  1556 ?        S    06:35   0:00 sshd: dotcloud@pts/0
dotcloud   190  0.0  0.0  19416  2100 pts/0    Ss   06:35   0:00  \_ /bin/bash
dotcloud   204  0.0  0.0  15292  1148 pts/0    R+   06:36   0:00      \_ ps auxwwf
dotcloud   146  0.0  0.0  42016 11608 ?        Ss   04:17   0:01 /usr/bin/python /usr/bin/supervisord.real
dotcloud   153  0.0  0.0  73500 22516 ?        S    04:17   0:00  \_ /usr/local/bin/uwsgi --pidfile /var/dotcloud/uwsgi.pid -s /var/dotcloud/uwsgi.sock --chmod-socket=660 --master --processes 4 --psgi app.psgi --disable-logging
dotcloud   165  0.0  0.0  73500 19728 ?        S    04:17   0:00      \_ /usr/local/bin/uwsgi --pidfile /var/dotcloud/uwsgi.pid -s /var/dotcloud/uwsgi.sock --chmod-socket=660 --master --processes 4 --psgi app.psgi --disable-logging
dotcloud   166  0.0  0.0  73500 19728 ?        S    04:17   0:00      \_ /usr/local/bin/uwsgi --pidfile /var/dotcloud/uwsgi.pid -s /var/dotcloud/uwsgi.sock --chmod-socket=660 --master --processes 4 --psgi app.psgi --disable-logging
dotcloud   167  0.0  0.0  73500 19728 ?        S    04:17   0:00      \_ /usr/local/bin/uwsgi --pidfile /var/dotcloud/uwsgi.pid -s /var/dotcloud/uwsgi.sock --chmod-socket=660 --master --processes 4 --psgi app.psgi --disable-logging
dotcloud   168  0.0  0.0  73500 19728 ?        S    04:17   0:00      \_ /usr/local/bin/uwsgi --pidfile /var/dotcloud/uwsgi.pid -s /var/dotcloud/uwsgi.sock --chmod-socket=660 --master --processes 4 --psgi app.psgi --disable-logging
{% endhighlight %}

这下看到了，其实就是用uwsgi运行psgi程序。题外话：发现用的是supervisord做进程管理。
这个时候就可以通过http://myapp-on-dotcloud.dotcloud.com/访问到dancer的index页面了~熟悉的dancing。。。。可以看到，整个dotcloud环境是比较接近server环境的，除了上传的几个特殊文件以外，基本跟普通的dancer开发web一样。
