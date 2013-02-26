---
layout: post
title: PostgreSQL中国用户会DBA2000培训计划北京第二课笔记
date: 2012-03-18
category: database
tags:
  - PostgreSQL
---

## 运行维护

### vacuum命令

pgsql是multi-version concurrency control的，update和delete的操作并不会真正的修改原版本的内容，而只是做一个标记，最后需要用vacuum命令回收失效版本的位置。  
vacuum的主要作用：
1. 恢复或重用失效的空间；
2. 更新pgsql规划器的数据统计；
3. 避免事务ID的重复。
事务ID只有32位，差不多40亿左右。建议在达到10亿左右的时候就需要vacuum一次。  
在version8.*之后，默认就是用auto vacuum。注意auto vacuum不是定时启动，而是触发式的。

vacuum命令有两种形式：
1. vacuum，正常情况，不阻塞读写。
2. vacuum full，使用全表排他锁，不可读，产生最小大小的数据文件。不建议在7*24的生产环境使用。

vacuum full命令的操作原理简述：
1. 标记旧数据；
2. 移动数据成连续空间；
3. 截断文件。

### reindex命令

在version7.4之后，该命令不再需要经常性运行了。  
执行该命令会阻塞写操作。读操作照常。

### analyze命令

建议规划一个database范围的analyze，然后每天运行看效果。

## 存储过程

### pl/pgsql示例：

{% highlight sql %}
CREATE FUNCTION func_name ( option type ) RETURNS
    type AS $$
    ...
{% endhighlight %}

### 触发器示例：

{% highlight sql %}
CREATE FUNCTION trigger_name ( option type ) RETURNS
    tirgger AS $$
DECLARE ...
BEGIN
    ....
    RETURN NEW/NULL /*NULL就回滚上面的操作*/
END
{% endhighlight %}

### 调试

图形化安装时带有的pgadmin3里有一项debugger。  
配置：shared_preload_libraries="$libdir/plugins/plugin_debugger.so"  
导入：debugger.sql

## 监控

1. data/pg_log/*.log

标示等级一般为：通用等级LOG NOTICE，错误等级FATAL ERROR，提示等级LOG HINT
一般有一个startup.log文件记录启动过程；一些以时间为名字的日志，记录运行过程，每当文件超过10MB，每次重启，以及每过一整天的时候，就会生成一个新文件。

2. pgadmin3

通过server status看锁状态，杀进程等。

3. psql命令

{% highlight sql %}
select * from pg_stat_activetity;
{% endhighlight %}
配置：log_min_duration_statement，设置慢查询日志的时限，单位为毫秒。

## 集群

### 8.*时代

复制以WAL File为单位，一旦丢失，就可能损失16MB的事务。而且standby不可读。

### 9.*时代

复制以WAL中的record为单位，且standby可以读操作，能设置成读写分离集群。
9.0中只有异步复制；9.1中有同步复制。

### 主要方案

PGPool II等

