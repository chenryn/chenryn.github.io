---
layout: post
theme:
  name: twitter
title: PostgreSQL中国用户会DBA2000培训计划北京第一课笔记
date: 2012-03-17
category: database
tags:
  - PostgreSQL
---

# PostgreSQL及中国用户会简介

  主讲人 李元佳 galy

## 数据库分类

  商业数据库: Oracle, DB2, SQLserver, Sybase...
  开源数据库: MySQL, PostgreSQL, Firebird, SQLite, Apache Derby...

## PostgreSQL沿革

  类BSD许可的，面向对象的，关系型数据库管理系统。

  MIT --> Ingres --> Postgres --> PostgreSQL ( 同源的还有SQLserver等 )

  支持SQL2008标准的大部分功能特性，是各种RDBMS的SQL方言中最贴近标准的。

# PostgreSQL简介

  主讲人 萧少聪 Scott.Siu

## 用户与进程

![postgreSQL中用户与进程的联系](/images/uploads/pgsql-process.png)

注意在上图中，不管是workmem还是sharebuffer，每个page都是8KB大小。

## 复制流程

  stream replica的流程如下：

	client --> postgres --> WAL (not file)--> slave --> (return OK) --> master --> commit

  在master上的流程细节如下：

	client --> write-ahead log(WAL) buffer --> commit --> (async/fsync~~160%) --> WAL Files (16MB * 132个)
	   ^
	   |--> share buffer  --> bgwriter --> db files
	             ^                            |
	             |--        check point     <--
## 安装

  linux: 注意使用独立的非root用户来安装启动pgsql。在version9.1后，可以跟SElinux结合使用，提高安全性。  
  win: 只能在NTFS文件系统上创建表空间。  
  窗口统一式安装，可以方便的安装stack builder套件。

## 目录

  默认使用窗口安装的情况下，目录结构如下：

	/opt/PostgreSQL/9.1/
	    |
	    |--> bin/
	    |--> doc/
	    |--> include/
	    |--> lib/
	    |--> share/
	    |--> install/
	    |--> data/
	           |--> base/		存放table和index的ID号
	           |--> global/
	           |--> pg_clog/	运行日志
	           |--> pg_xlog/	WAL日志
	           |--> pg_tblspc/	表空间ID，实质为到真实数据目录的软连接
	           |--> postgresql.conf
	           |--> pg_hba.conf

## 创建

1. 使用bin/initdb命令；  
2. 修改data/pg_hba.conf里的连接地址段和登录权限；  
3. 修改data/postgresql.conf里的监听网卡。

## 启动与停止

使用bin/pg_ctl命令。其停止命令可指定三种类型：

1. smart模式，即等待全部client连接断开后停止；  
2. fast模式，即直接回滚全部尚未完成的事务后停止；  
3. immediate模式，即立刻中止全部进程。

## 配置说明

1. work_mem:    
并不是每个client连接的postgres进程分配一个work mem，而是SQL每一次的排序work使用一个work mem。包括join和order by。如果没有排序，就不用work mem。如果一条sql里同时使用了N次排序，那么就要使用N个work mem。所以理想的使用方法不是提供太大的work mem来排序，而是尽量缩小需要排序的数据大小，设置为4/8MB即可。    
该配置是可以online修改的。命令如下：    
	SET work_mem = 2048;
	SET work_mem = '2MB';
上面两条命令等价。可以看书其计量单位为1KB，且类型为字符串，所以在自定义计量时需要用引号。

2. share_buffers:    
理论上为机器物理内存的40%大小。实际测试显示大于8GB后，性能不会有相应的提升，即可认为最大设置到8GB。

3. temp_buffers:    
无修改意义

4. max_prepared_transactions:    
并发事务数

5. maintenance_work_mem:    
vacuum、create index、alter table add foreign key等管理命令使用的work_mem，建议设置1G。因为这些命令经常涉及全表扫描。

## postgreSQL的数据集概念

	                      DataBase Cluster
	                             |
	                   |---------|---------|
	                   |         |         |
	                 user     database   tablespace
	                             |
	                           schema

  这里的cluster不是HA cluster，而是数据集。  
  一个database里可以有多个schema，一个user可以有多个schema的管理权限，但一个schema只能归属于一个user。  
  默认有一个template0为schema的基础，不可修改，在template0基础上有template1，可以修改。实际创建schema时就是复制template1出来。
  创建user时，一般都会再创建一个同名的schema，并规定该schema的所属人为该user。这样在pgsql连接到database后，其默认schema即为该同名schema。

## 备份与恢复

### 备份

pg_dump命令，使用-s指定只备份数据结构，-t指定只备份数据内容。

### 基于时间点的备份恢复

1. select pg_start_backup('FullBackup');
2. tar zcvf full_backup/week1.tgz /opt/PostgreSQL/9.1/data/
3. select pg_stop_backup();

1. tar zxvf full_backup/week1.tgz -C /
2. echo 'restore_command="cp %f %p"' > data/recovery.conf

