---
layout: post
title: Graphite 安装
categroy: monitor
tags:
  - python
  - graphite
---

Graphite 是近来比较流行的类 rrd tool 系统。不过官网的安装文档真的很烂，特记录一下自己的步骤。

由于是事后追忆，同样不保证好用……

{% highlight bash %}
apt-get install python-pip libapache2-mod-wsgi subversion git
git clone https://github.com/graphite-project/graphite-web.git
git clone https://github.com/graphite-project/carbon.git
git clone https://github.com/graphite-project/whisper.git
# 这两个是直接通过 pip 安装的不顶用，只能另外下非标准的包安装
git clone https://github.com/graphite-project/ceres.git
svn checkout http://django-tagging.googlecode.com/svn/trunk/ tagging-trunk

cd whisper
sudo python setup.py install

cd ../carbon
python setup.py install 

cd ../graphite-web
python check-dependencies.py
# 很奇怪 python 居然不自动解决依赖，check 出来一个列表还得自己来
apt-get install python-memcache python-txamqp python-rrdtool python-pyparsing python-django
python setup.py install

cd ../ceres
python setup.py install

cd ../tagging-trunk
python setup.py install

groupadd graphite
ln -s /opt/graphite/examples/example-graphite-vhost.conf /etc/apache2/conf.d/graphite.conf
# 默认的 run/wsgi 会在 /etc/apache2/ 目录下，权限有问题
sed -i 's!^\(WSGISocketPrefix\) \(run/wsgi\)$!\1 /var/\2$!' /etc/apache2/conf.d/graphite.conf
chown -R www-data:graphite /opt/graphite/storage/
service apache2 restart

cd /opt/graphite/webapp/graphite
cp local_settings.py.example local_settings.py
# 默认的 database 配置是针对 python2.4 的，需要开启针对 python2.5 以上版本的配置:
# DATABASES = {
#     'default': {
#         'NAME': '/opt/graphite/storage/graphite.db',
#         'ENGINE': 'django.db.backends.sqlite3',
#         'USER': '',
#         'PASSWORD': '',
#         'HOST': '',
#         'PORT': ''
#     }
# }
sed -i '167,176s/^#//' local_settings.py
python manage.py syncdb

cd /opt/graphite/conf
rename 's/.example//' *.conf.example

cd /opt/graphite/
# 会监听 2003 端口
./bin/carbon-cache.py start

# 通过 socket 发送本机的 loadavg 到 2003 端口
python /opt/graphite/examples/example-client.py
{% endhighlight %}

效果如下：

![graphite](/images/uploads/graphite-auto-refresh.png)

还可以点击 plot 成下面这样，并且添加 event 以供查看：

![graphlot](/images/uploads/graphite-graphlot.png)

