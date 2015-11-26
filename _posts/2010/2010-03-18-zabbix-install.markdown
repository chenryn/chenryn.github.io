---
layout: post
title: zabbix安装试用
date: 2010-03-18
category: monitor
---

在CU上看到有帖子比较各开源monitor软件，其中对zabbix颇多赞誉。决定试用一下。
```bash
#为快速安装方便，LAMP环境都采用yum获取。
yum install httpd mysql* php* gcc net-snmp* curl*
#然后编译安装zabbix，步骤如下：
groupadd zabbix
useradd -g zabbix zabbix
wget http://cdnetworks-kr-1.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/1.8.1/zabbix-1.8.1.tar.gz
tar zxvf zabbix-1.8.1.tar.gz
cd zabbix-1.8.1
mysql -uroot -p
>create database zabbix;
>grant all privileges on zabbix.* to zabbix@"localhost" identified by '123456';
>flush privileges;
mysql -uroot -p zabbix < create/schema/mysql.sql
mysql -uroot -p zabbix < create/data/data.sql
mysql -uroot -p zabbix < create/data/images_msql.sql
./configure --prefix=/home/zabbix --enable-server --enable-proxy --enable-agent --with-mysql --with-net-snmp --with-libcurl
make && make install
cat >> /etc/services <<EOF
zabbix-agent    10050/tcp            # Zabbix Agent
zabbix-agent    10050/udp            # Zabbix Agent
zabbix-trapper    10051/tcp            # Zabbix Trapper
zabbix-trapper    10051/udp            # Zabbix Trapper
EOF
make /home/zabbix/conf
cp misc/conf/* /home/zabbix/conf/
ln -s /home/zabbix/conf /etc/zabbix
chown -R zabbix.zabbix /etc/zabbix
i=`hostname`;sed -i "s/^Hostname=system.uname/Hostname=$i" /etc/zabbix/zabbix_agentd.conf
sed -i 's/^DBUser=root/DBUser=zabbix/g' /etc/zabbix/zabbix_server.conf
sed -i 's/^# DBPassword=/DBPassword=zabbix/g' /etc/zabbix/zabbix_server.conf
mv frontends/php /var/www/html/zabbix
chown -R zabbix.zabbix /var/www/html/zabbix
```
根据zabbix需求修改LAMP，vi /etc/php.ini修改相关参数如下：

    max_execution_time = 300
    date.timezone = Asia/Shanghai
    post_max_size = 32M
    memory_limit = 128M
    mbstring.func_overload = 2

vi /etc/httpd/conf/httpd.conf修改servername，然后启动apache。

服务器操作部分完成，接下来是web配置。

浏览器打开http://mydomain.com/zabbix，出现setup.php，按说明next即可。到最后要求下载zabbix.conf.php。其实可以直接修改服务器文件。

```bash
sed -i 's/0";/3306";/g' /var/www/html/zabbix/conf/zabbix.conf.php.example
sed -i 's/_password//g' /var/www/html/zabbix/conf/zabbix.conf.php.example
mv /var/www/html/zabbix/conf/zabbix.conf.php.example /var/www/html/zabbix/conf/zabbix.conf.php
```

然后test即可OK，进行登陆界面。初始用户名密码为admin/zabbix。
进去以后，第一件事改密码。
选择administrator下的user，点击admin，change password即可；还可以添上email等信息；另外，可以选择chinese，save之后relogin，可以看到稍微友好一点点的中文界面，不过翻译水平就请将就一下吧~~（最无语的是把select翻译成搜索==!）
<a href="http://www.hiadmin.com" target="_blank">架构研究室</a>刚刚发布了一个汉化全面一些的<a href="http://www.hiadmin.com/wp-content/uploads/2010/03/cn_zh.inc.php_.tar.gz" target="_blank">语言包</a>，可以解压覆盖/var/www/html/zabbix/include/locales/cn_zh.inc.php。
开始在页面上点点看看吧，不过这时候才想起来，web虽然开了，zabbix服务本身却一直没有启动呢~返回服务器操作：
```bash
cp misc/init.d/redhat/zabbix_* /etc/init.d/
```
vi /etc/init.d/zabbix_server_ctl，把BASEDIR改成/home/zabbix，PIDFILE=/var/tmp修改成PIDFILE=/tmp/，$BASEDIR/bin/改成$BASEDIR/sbin/。zabbix_agentd_ctl同理。

然后，启动服务，/etc/init.d/zabbix_server_ctl start;/etc/init.d/zabbix_agentd_ctl start

（网上都没写pid路径也要改，实际上zabbix_server.conf里的路径是/tmp/zabbix_server.pid，不改会导致启动脚本失效）

zabbix和nagios等监控一样，需要在被监控host上安装agent来完成数据采集和其他操作。当然，如果就是不肯安装的话，也可以使用snmp来完成一些基本的东西。
host上的agent部署特别简单：
```bash
wget http://www.zabbix.com/downloads/1.8/zabbix_agents_1.8.linux2_6.x64.tar.gz
tar zxvf zabbix_agents_1.8.linux2_6.x64.tar.gz -C /home/
cat >> /home/zabbix/conf/zabbix_agentd.conf << eof
LogFile=/tmp/zabbix_agentd.log
Server=zabbix服务器的ip
Hostname=被监控host的名字
eof
```
然后启动即可。/home/zabbix/sbin/zabbix_agentd -c /home/zabbix/conf/zabbix_agentd.conf &

据称这里如果不写全路径，可能出错。

进入使用环节咯。大体上monitor都是这样，groups-hosts-templates-items-triggers-graphs-actions
create一个新host group，太简单，略过；    
create一个新host，主要选择group、link相应的template；    
返回host列表，就可以选择它们自己的items、trigger、graph了。需要注意的是原有的trigger是从template里读出来的，所以修改的话也要从template里修改。    
action是报警方式，比如上面编辑user时加的email，这里可以在add operations的时候选择send message给某user（不要忘了在administration的media types里配smtp），还可以选择remote command；另外add conditions的时候，选择具体是哪些主机、那些trigger等等。    
graph是绘图，有阴影、连线、散点等方式，只要是items里有的，都能绘图出来。重叠在一张图里显示的时候，不要忘了改成好区分的颜色，一目了然~~常见的自然是流量、负载、磁盘使用等等图。    
web是对url的监控，这个比nagios等要强大多了。因为使用libcurl，它可以模拟各种user-agent下的访问，还能post数据模拟一系列操作（登陆、发帖、收藏等等，先在variables里定义好变量，然后在step中传递）。添加完成后，就可以看到对这些url的响应速度和时间的监控图了。完成后，在该host的trigger中，select items还增加了web monitor项，分别是速度、时间、状态码，也可以对此进行报警。    
_to_be_continued_


