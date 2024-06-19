---
layout: post
theme:
  name: twitter
title: blog备份脚本
date: 2011-10-24
category: perl
tags:
  - perl
  - mysql
---

之前总不重视自己的博客，上回一丢才心疼，现在重视起来，决定定期备份sql。写个小脚本如下：
```perl#!/usr/bin/perl
use warnings;
use strict;
use MySQL::Backup;
use Mail::Sender;
open my $tmp_sql, '>', "backup.sql";
my $mb = new MySQL::Backup('dbname', 'localhost', 'dbuser', 'dbpasswd', {'USE_REPLACE' => 1, 'SHOW_TABLE_NAMES' => 1});
print $tmp_sql $mb->create_structure();
print $tmp_sql $mb->data_backup();
close $tmp_sql;
my $sender = new Mail::Sender { smtp    => 'smtp.163.com',
                                from    => 'mailuser@163.com',
#                                debug   => 'backup_debug.log',
                                auth    => 'LOGIN',
                                authid  => 'mailuser',
                                authpwd => 'mailpasswd',
                              };
$sender->MailFile({ to      => 'mailuser@gmail.com',
                    subject => 'Backup Blog SQL_'.time(),
                    msg     => '3Q',
                    file    => 'backup.sql',});```
没有直接用mysqldump，而是找了这个MySQL::Backup模块，试着看了导出的sql，和mysqldump的结果是有些不同的。
mysqldump导出的sql一般结构是这样子：
```mysqlDROP TABLE IF EXISTS `tablename`;
CREATE TABLE `tablename`(ID INT NOT NULL ...);
LOCK TABLES `tablename` WARITE;
INSERT INTO `tablename` VALUES(...),(...),(...);
UNLOCK TABLES;```
而MySQL::Backup导出的sql结构是这样子的：
```mysqlCREATE TABLE `tablename`(ID INT NOT NULL ...);
REPLACE INTO `tablename`(ID,...)VALUES(1,...);
REPLACE INTO `tablename`(ID,...)VALUES(2,...);```
其实我不太清楚replace比insert好在那，不过pod上的example用了USE_REPLACE=>'1'，就照抄了，如果习惯insert的，在new构建对象时，不用这个param就行了。
另外这个Mail::Sender模块，是在微博上某次评论时，发现很多朋友在用的，我也就放弃一次Net::SMTP_auth，用一次试试，感觉还不错~~
