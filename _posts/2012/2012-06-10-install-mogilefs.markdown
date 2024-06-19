---
layout: post
theme:
  name: twitter
title: MogileFS安装
date: 2012-06-10
category: perl
---

纯属凑数的更新，写写安装过程而已。没有调优，没有测评，嗯……

* storage Node

```bash
cpanm MogileFS::Utils MogileFS::Client
# 因为MogileFS::Server的test里会测试mysql、sqlite、pgsql的支持，用不着，直接强制安装就好了
cpanm --force MogileFS::Server
mkdir /etc/mogilefs
cat > /etc/mogilefs/mogstored.conf <<EOF
maxconns = 10000
httplisten = 0.0.0.0:7500
mgmtlisten = 0.0.0.0:7501
docroot=/data/mogstore
EOF
# 不在同一分区的磁盘采用软连接方式建立伪DEV设备
mkdir /data/mogstore/dev170
mkdir /data1/mogstore
ln -s /data1/mogstore /data/mogstore/dev171
```

* Tracker

```bash
yum install -y mysql-server mysql-devel
cpanm DBI DBD::mysql MogileFS::Utils MogileFS::Client
cpanm --force MogileFS::Server
```

```sql
CREATE DATABASE MogileFS DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
grant all on MogileFS.* to 'mogile'@'%' identified by 'mogile';
UPDATE mysql.user SET Password=PASSWORD('newpass') WHERE User='mogile';
FLUSH PRIVILEGES;
```

```bash
# 初始化mysql数据库表
mogdbsetup --dbhost=tracker.mogile.com --dbname=MogileFS --dbuser=mogile --dbpass=newpass
mkdir /etc/mogilefs
cat > /etc/mogilefs/mogilefsd.conf <<EOF
db_dsn = DBI:mysql:MogileFS:host=tracker.mogile.com
db_user = mogile
db_pass = mogile
listen = 0.0.0.0:7001
conf_port = 7001
query_jobs = 10
delete_jobs = 1
replicate_jobs = 5
reaper_jobs = 1
EOF
# mogilefsd不能用root启动
useradd mogile
su - mogile -c 'mogilefsd -c /etc/mogilefs/mogilefsd.conf --daemon'
# 添加storage node和相关伪DEV设备信息
mogadm host add mognode17 --ip=10.0.0.17 --port=7500 --status=alive
mogadm device add mognode17 170
mogadm device add mognode17 171
# 添加域和类。文件的key在同一域内是唯一的。同一类可以指定自己的复制份数
mogadm domain add fmn
mogadm class add fmn large --mindevcount=3
mogadm class add fmn small --mindevcount=3
# 检查状态，类似的有mogadm check命令
mogstats --db_dsn="DBI:mysql:MogileFS:host=tracker.mogile.com" --db_user="mogile" --db_pass="mogile" --verbose --stats="all"
# 插入一个文件做测试
mogtool --debug --trackers=127.0.0.1:7001 --domain=fmn --class=large inject index.html "index.html"
```

* Fuse

这步没搞出来，因为search.cpan.org上的Fuse是0.14版本，cpanm安装居然说无法下载的是0.15版。而MogileFS::Client::Fuse里use的是0.11版……
而且直接下载的Fuse0.14版源码编译还一直通不过make test。。。

最后在github上找到两个资源：
[Fuse-0.15](https://github.com/dpavlin/perl-fuse)    
[Mogile-Fuse-0.03](https://github.com/frett/MogileFS-Fuse)    

先解决依赖：
```bash
yum install -y fuse fuse-devel fuse-libs
cpanm FUSE::Client FUSE::Server Lchown Filesys::Statvfs Unix::Mknod
```
然后perl Makefile.PL && make && make test && make install即可。
挂载命令是：
mount-mogilefs --daemon --tracker 10.0.0.16:7001 /mnt/mogilefs
不过目前为止我挂载上去依然无法使用，输入输出有问题……
