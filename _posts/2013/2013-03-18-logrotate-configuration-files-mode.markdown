---
layout: post
title: logrotate 配置文件强制为 0644 属性
category: linux
tags:
  - C
---

在一次包更新后，发现 Nginx 服务器的每晚日志切割不再进行了。找遍了各种地方，最后在一次偶然的`ls -l`中发现：

```bash
# ll /etc/logrotate.d/
total 64
-rw-r--r-- 1 root root  326 2012-08-04 06:08 apache2
-rw-r--r-- 1 root root   84 2009-02-08 05:18 apt
-rw-r--r-- 1 root root   79 2008-12-05 17:15 aptitude
-rw-r--r-- 1 root root  330 2008-03-08 05:36 atop
-rw-r--r-- 1 root root  232 2011-11-10 14:33 dpkg
-rw-r--r-- 1 root root  267 2013-01-31 13:20 foreman-proxy
-rw-r--r-- 1 root root  151 2007-09-29 19:23 iptraf
-rw-r--r-- 1 root root  880 2012-10-29 17:10 mysql-server
-rwxr-xr-x 1 root root  356 2012-08-05 00:17 nginx
-rw-r--r-- 1 root root 1061 2008-03-08 05:36 psaccs_atop
-rw-r--r-- 1 root root  512 2008-03-08 05:36 psaccu_atop
-rw-r--r-- 1 root root  260 2012-06-23 00:52 rabbitmq-server
-rw-r--r-- 1 root root  126 2012-06-09 00:22 redis-server
-rw-r--r-- 1 root root  515 2012-09-27 02:40 rsyslog
-rw-r--r-- 1 root root  285 2008-11-18 21:20 stunnel4
```

这里的nginx多了可执行权限。于是我尝试性的执行了`chmod -x nginx`；结果居然真的恢复了。

这事儿说起来蛮奇怪了。于是去 <https://fedorahosted.org/logrotate> 找来 logrotate 的源码看，结果在`logrotate-3.8.3/config.c` 里发现这么一段：

```c
 661                 if ((sb.st_mode & 07533) != 0400) {
 662                         message(MESS_DEBUG,
 663                                 "Ignoring %s because of bad file mode.\n",
 664                                 configFile);
 665                         close(fd);
 666                         return 0;
 667                 }
```

只有文件权限是 0644 的时候，配置文件才会被读取！0755 的与结果是 0511，不等于 0400。相关 `st_mode` 的内容可以通过 `man 2 stat` 查看。

可以写一小段 perl 代码来验证：

```perl
#!/usr/bin/perl
my $mode = (stat($ARGV[0]))[2];
printf "Permissions are %04o\n", $mode & 07533;
```

在 [ChangeLog](https://fedorahosted.org/logrotate/browser/tags/r3-8-3/CHANGES) 里，看到如下一段话：

    2.1 -> 2.2:
        - ignore nonnormal files when reading config files from a directory
        - (these were suggested and originally implemented by
          Henning Schmiedehausen)

不过比较早了，就懒得从历史堆里再翻为什么当初会有这么个提议了…………
