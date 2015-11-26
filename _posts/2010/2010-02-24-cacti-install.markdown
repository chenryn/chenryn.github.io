---
layout: post
title: cacti安装记录
date: 2010-02-24
category: monitor
tags:
  - cacti
---

cacti运行在lamp环境下，采用net-snmp获得监控数据，由rrdtool绘图。所以cacti的安装，主要就是apache、mysql、php、rrdtool、net-snmp这几个的安装。其中apache2是我们服务器上早就有的，可以利用；而原有的php5因为不支持mysql，所以要重新编译。

1. mysql安装：

```bash
wget http://mysql.cs.pu.edu.tw/Downloads/MySQL-5.1/mysql-5.1.44.tar.gz
tar zxvf mysql-5.1.44.tar.gz
cd mysql-5.1.44
groupadd mysql
useradd mysql -g mysql
./configure --prefix=/home/mysql --with-unix-socket-path=/tmp/mysql.sock --localstatedir=/cache/mysql --enable-assembler --with-mysqld-ldflags=-all-static --with-client-ldflags=-all-static --with-extra-charsets=gbk,gb2312,utf8 --enable-thread-safe-client --with-big-tables --enable-local-infile --with-ssl --with-mysqld-user=mysql
make
make install
cd support-files/
cp my-medium.cnf /etc/my.cnf
cp mysql.server /etc/rc.d/init.d/mysqld
cd ../scripts/
./mysql_install_db --user=mysql
mkdir –p /cache/mysql
chown -R mysql.mysql /cache/mysql/
chgrp -R mysql /home/mysql/
chmod 700 /etc/rc.d/init.d/mysqld
ln -s /etc/rc.d/init.d/mysqld /etc/rc.d/rc3.d/S97mysqld
chmod 777 /tmp/
/home/mysql/bin/mysqld_safe --user=mysql &amp;
ln –s /home/mysql/bin/* /usr/bin/
sed -i /^myisam/aset-variable=wait_timeout=200 /etc/my.cnf
sed -i /^myisam/aset-variable=max_user_connections=500 /etc/my.cnf
sed -i /^myisam/aset-variable=max_connections=1000 /etc/my.cnf
/etc/init.d/mysqld restart
```

2. php安装

```bash
wget http://cn.php.net/distributions/php-5.2.12.tar.gz
tar zxvf php-5.2.12.tar.gz
cd php-5.2.12
./configure --prefix=/home/php --with-apxs2=/home/apache2/bin/apxs --with-mysql=/home/mysql --enable-sockets --with-zlib-dir=/usr/include --with-gd --with-snmp --enable-ucd-snmp-hack --with-ttf --enable-mbstring --enable-xml --with-mysql-sock=/tmp/mysql.sock
# (注：apache版本不同，--with-apxs2可能要写成--with-apxs)
make
make install
cp php.ini-dist /home/php/lib/php.ini
ln -s /home/php/bin/* /usr/local/bin/
```

3、apache检测

```bash
# grep php /home/apache2/conf/httpd.conf
DirectoryIndex index.php index.html index.htm
AddType application/x-httpd-php .php
LoadModule php5_module        modules/libphp5.so
# /home/apache2/bin/apachectl configtest
Syntax OK
# cat >> /cache/data/index.php <<EOF
<?php
phpinfo();
?>
EOF
# curl http://localhost | grep module_mysql
<h2><a name="module_mysql">mysql</a></h2>
```

4、rrdtool安装
麻烦东西来了，网上很多cacti部署教程，都在rrdtool上大费周章，因为这个东东依赖的库文件很多，而且自己本身的版本不同，库文件的种类和版本要求也不一样。首先，尽可能的把这些东西都安装吧：

    rpm -qa|grep lm_sensors
    rpm -qa|grep beecrypt
    rpm -qa|grep libpng
    rpm -qa|grep elfutils
    rpm -qa|grep sensors
    rpm -qa|grep pixman
    rpm -qa|grep freetype
    rpm -qa|grep fontconfig
    rpm -qa|grep net-snmp
    rpm -qa|grep libart_lgpl
    rpm -qa|grep zlib
    rpm -qa|grep glib
    rpm -qa|grep libxml2
    rpm -qa|grep intltool
    rpm -qa|grep cairo
    rpm -qa|grep pango

# find / –name pangocairo.pc，如果没有，就要把cairo和pango重装了，务必先cairo后pango。
如果以上齐全，可以去http://oss.oetiker.ch/rrdtool/pub/libs下载rrdtool的源码编译，然后按照make的warning信息慢慢调整库文件的相应版本号去了……

如果不要求自己成为编译达人，只求搞定的，那么按照如下办法，轻松搞定吧：
```bash
# cat > /etc/yum.repos.d/ct5_64.repo <<EOF
[base]
name=CentOS-5.4 - Base
baseurl=http://mirrors.163.com/centos/5.4/os/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5
EOF
# yum install ruby xorg-x11-fonts-Type1

# cat > /etc/yum.repos.d/ct5_64.repo <<EOF
[base]
name=CentOS-5.4 – Base
baseurl=http://apt.sw.be/redhat/el$releasever/en/$basearch/dag
gpgcheck=1
gpgkey=http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt
enabled=1
EOF
# rpm --import <a href="http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt">http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt</a>
# yum install rrdtool
```
（还嫌不够简单？那还有更简单的：
wget http://dag.wieers.com/rpm/packages/rpmforge-release/rpmforge-release-0.3.6-1.el5.rf.x86_64.rpm;rpm -Uvh rpmforge-release-0.3.6-1.el5.rf.x86_64.rpm;yum install rrdtool rrdtool-php即可）

5、cacti安装
```bash
# wget http://www.cacti.net/downloads/cacti-0.8.7e.tar.gz
# tar zxvf cacti-0.8.7e.tar.gz –C /cache/data/
# mv /cache/data/cacti-0.8.7e /cache/data/cacti
# cd /cache/data/cacti
# mysql -uroot –p
mysql> create database cacti;
mysql> grant all privileges on cacti.* to <a href="mailto:cacti@&quot;localhost">cacti@"localhost</a>" identified by '123456';
mysql> flush privileges;
# /home/mysql/bin/mysql -ucacti -p cacti < cacti.sql
# useradd cacti -d /cache/data/cacti -s /bin/false
# chown -R cacti rra
# chown -R cacti log
# sed –i 's/username = "cactiuser/username = "cacti/' include/config.php
# sed –i 's/password = "cactiuser/password = "123456/' include/config.php
# echo '*/5 * * * * /home/php/bin/php /cache/data/cacti/poller.php &amp;> /dev/null' >>/var/spool/cron/root
```

6、web页面发布
在httpd.conf中发布
```apache
<Directory /cache/data>
    Options Indexes FollowSymLinks
    AllowOverride None
    Order Allow,Deny
    Allow from all
</Directory>
```

大功告成，接下来都是鼠标的事了，在browser中登陆http://yourdomian/cacti，按实际情况修改php/mysql/net-snmp的which和version信息，一路next即可，最后，cacti的初始用户名密码都是admin。

