---
layout: post
title: cdn自主监控(三):数据库准备工作
date: 2011-07-27
category: monitor
tags:
  - MySQL
---

准备两个表，一个存储原始数据，另一个存储每5分钟归总一次的数据。之后根据时间段绘制省份运营商性能图的时候，就直接从汇总表里获取数据；原始表留给详细查询。
数据库准备脚本如下：
{% highlight mysql %}USE myops;
CREATE TABLE IF NOT EXISTS cdn_ori_record (
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	ip INT(10) NOT NULL DEFAULT '0000000000',
	isp ENUM('0','1','2','3','4'),
	area INT(4) NOT NULL DEFAULT '0000',
	cur_date TIMESTAMP DEFAULT NOW(),
	cdn_time INT(10) NOT NULL DEFAULT '0',
	cdn ENUM('CHINACACHE','DNION','FASTWEB') NOT NULL,
	KEY time_key (cur_date)
);

CREATE TABLE IF NOT EXISTS cdn_cron_record (
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	isp TINYINT(1) NOT NULL DEFAULT '0',
	area INT(4) NOT NULL DEFAULT '0000',
	cur_date TIMESTAMP DEFAULT NOW(),
	cdn ENUM('CHINACACHE','DNION','FASTWEB') NOT NULL,
	avg_time INT(10) NOT NULL DEFAULT '0',
	KEY time_area_isp_key (cur_date, area, isp)
);

DELIMITER |
DROP PROCEDURE IF EXISTS cdn_cron |
CREATE PROCEDURE cdn_cron()
BEGIN
	INSERT INTO cdn_cron_record(isp,area,cdn,avg_time) 
	SELECT isp,area,cdn,AVG(cdn_time) FROM cdn_ori_record 
	WHERE cur_date > FROM_UNIXTIME(UNIX_TIMESTAMP()-300)
	GROUP BY cdn,area,isp;
END |
DELIMITER ;

SET GLOBAL event_scheduler = 1;
CREATE EVENT IF NOT EXISTS event_cdn ON SCHEDULE EVERY 300 SECOND ON COMPLETION PRESERVE DO CALL cdn_cron();
ALTER EVENT event_cdn ON COMPLETION PRESERVE ENABLE;
{% endhighlight %}
