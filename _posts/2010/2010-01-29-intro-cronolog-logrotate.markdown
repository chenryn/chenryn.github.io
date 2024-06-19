---
layout: post
theme:
  name: twitter
title: 日志管理
date: 2010-01-29
category: linux
tags:
  - apache
  - nginx
  - logrotate
---

第一个，最常见的cronolog，因为他配对apache，apache太常见，所以cronolog也就常见了~~稳定版本1.6.2，似乎不支持2G以上的日志，因为那时候linux内核也不支持。。。现在有beta版可以，另据网友分析，其实只要修改1.6.2源代码中的openfile函数成openfile64就行了……
使用方法：

    CustomLog "|/usr/local/sbin/cronolog /var/log/httpd/www/access%Y%m%d.log" combined

其实就是利用管道，传递给cronolog记录日志。
对于不支持在配置文件里利用管道的，也有别的变通办法，比如命名管道。像nginx日志就能这么做：

mkfifo /path/to/nginx/logs/access_log_pipe
/path/to/cronolog /path/to/log/access_%Y%m%d.log /path/to/nginx/logs/access_log_pipe &

然后编辑nginx.conf，修改如下：

access_log /path/to/nginx/logs/access_log_pipe combined

最后要注意的是，必须在启动nginx之前，先启动cronolog。

第二个，系统自带的logrotate，一般系统本身的syslog、crond、yum等，都是用它。对于不必要保存所有的日志，采用这个回滚程式正当其时。/etc/logrotate.conf默认配置不算太复杂，还能使用include，不过其全部参数真是不少，如下表：

    参数			功能
    compress			通过gzip 压缩转储以后的日志
    nocompress			不需要压缩时，用这个参数
    copytruncate		用于还在打开中的日志文件，把当前日志备份并截断
    nocopytruncate		备份日志文件但是不截断
    create			mode owner group 转储文件，使用指定的文件模式创建新的日志文件
    nocreate			不建立新的日志文件
    delaycompress		和 compress 一起使用时，转储的日志文件到下一次转储时才压缩
    nodelaycompress		覆盖 delaycompress 选项，转储同时压缩。
    errors			address 专储时的错误信息发送到指定的Email 地址
    ifempty			即使是空文件也转储，这个是 logrotate 的缺省选项。
    notifempty			如果是空文件的话，不转储
    mail			address 把转储的日志文件发送到指定的E-mail 地址
    nomail			转储时不发送日志文件
    olddir			directory 转储后的日志文件放入指定的目录，必须和当前日志文件在同一个文件系统
    noolddir			转储后的日志文件和当前日志文件放在同一个目录下
    prerotate/endscript		在转储以前需要执行的命令可以放入这个对，这两个关键字必须单独成行
    postrotate/endscript	在转储以后需要执行的命令可以放入这个对，这两个关键字必须单独成行
    daily			指定转储周期为每天
    weekly			指定转储周期为每周
    monthly			指定转储周期为每月
    rotate			count 指定日志文件删除之前转储的次数，0 指没有备份，5 指保留5 个备份
    tabootext			[+] list 让logrotate 不转储指定扩展名的文件，缺省的扩展名是：.rpm-orig,
    .rpmsave,			v, 和 ~
    size			size 当日志文件到达指定的大小时才转储，Size可以指定bytes(缺省)以及KB(sizek)或者MB (sizem).

第三个，newsyslog，这个东西感觉是logrotate的兄弟版，因为其配置文件写法都是采用｛｝的方式，而且命名也这么针锋相对的。习惯了用logrotate的，对于不能回滚而要求分割保留的，可以试试这个。

logrotate的写法举例：

/path/to/wtmp{
    daily
    minsize 5M
    create 0644 root utmp
    rotate 1
}
newsyslog的写法举例：

    set squid_logpath = /usr/local/squid/var/logs
    set squid_log = /usr/local/squid/var/logs/access.log
    set date_squid_log = /usr/local/squid/var/logs/access%Y%M%D.log
    SQUID{
        restart: run
        /usr/local/squid/sbin/squid -k rotate
        log:  SQUID
        squid_log squid squid 644
        archive:
        SQUID date_squid_log 0
    }

第四个，也是万能的一个，嗯，就是自己写脚本，定时gzip……

