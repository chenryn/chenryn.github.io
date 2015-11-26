---
layout: post
title: cacti优化
date: 2010-03-25
category: monitor
tags:
  - cacti
---

首先，采用spine代替cmd.php来采集数据。
下载与cacti相应版本的spine和补丁：
```bash
wget http://www.cacti.net/downloads/spine/cacti-spine-0.8.7e.tar.gz
tar zxvf cacti-spine-0.8.7e.tar.gz -C /tmp
cd /tmp/cacti-spine-0.8.7e
wget http://www.cacti.net/downloads/spine/patches/snmp_v3_fix.patch
wget http://www.cacti.net/downloads/spine/patches/mysql_client_reconnect.patch
wget http://www.cacti.net/downloads/spine/patches/ping_reliability.patch
patch -p1 -N < snmp_v3_fix.patch
patch -p1 -N < mysql_client_reconnect.patch
patch -p1 -N < ping_reliability.patch
./configure –prefix=/cache/data/cacti --with-mysql=/home/mysql
make
# 这个时候发现报错了，spine0.8.7e编译安装要求最新版本的automake1.11，于是去下automake：
wget http://ftp.gnu.org/gnu/automake/automake-1.11.tar.gz
tar zxvf automake-1.11.tar.gz -C /tmp/
cd /tmp/automake-1.11/
./configure --prefix=/usr
# 又报错，automake1.11要求新版本的autoconf2.64，于是去下autoconf：
wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.65.tar.gz
tar zxvf autoconf-2.65.tar.gz -C /tmp/
cd /tmp/autoconf-2.65/
./configure --prefix=/usr && make && make install
```

返回安装automake，即可成功；安装spine，也成功了。    
修改/cache/data/cacti/etc/spine.conf里的db信息，和cacti的global.php里一致。    
登陆web界面，settings中修改poller type为spine，修改Spine Specific Execution Parameters里的Maximum Threads per Process为cpu数的2倍。save~    
第二、给cacti-tables建index。默认的cacti.sql里一个index索引都没有~    
```sql
CREATE INDEX `data_template_data_id` ON `data_input_data` (`data_template_data_id`);
CREATE INDEX `host_id_snmp_query_id_snmp_index` ON data_local (`host_id`,`snmp_query_id`,`snmp_index`);
CREATE INDEX `local_data_id_data_source_name` ON data_template_rrd (`local_data_id`,`data_source_name`);
CREATE INDEX `graph_template_id_local_graph_id` ON graph_templates_item (`graph_template_id`,`local_graph_id`);
CREATE INDEX `local_graph_template_item_id` ON graph_templates_item (`local_graph_template_item_id`);
CREATE INDEX `host_id_snmp_query_id_snmp_index` ON host_snmp_cache (`host_id`,`snmp_query_id`,`snmp_index`);
CREATE INDEX `local_data_id_rrd_path` ON poller_item (`local_data_id`,`rrd_path`);
CREATE INDEX `host_id_rrd_next_step` ON poller_item (`host_id`,`rrd_next_step`);
CREATE INDEX host_id_snmp_query_id ON host_snmp_cache (host_id,snmp_query_id);
CREATE INDEX host_id_snmp_port ON poller_item (host_id,snmp_port);
CREATE INDEX data_source_path ON data_template_data (data_source_path);
```

第三、重构rra目录结构。按照device分结构。    
/home/php/bin/php /cache/data/cacti/cli/structure_rra_paths.php --proceed即可。    
web界面中settings里的Paths可以勾选Structured RRA Path(/host_id/local_data_id.rrd)即可。    

最后，据这个优化的<a target="_blank" href="http://zys.8800.org/index.php/archives/391/comment-page-1#comment-22">原作者</a>说，按此步骤，710台服务器，24000个RRD文件，完成一次poller.php的时间，缩短到50 seconds。
