---
layout: post
title: web服务监控小工具httping
date: 2010-05-06
category: monitor
---

今天偶然看到这个工具，感觉挺有用的，记录一下。
安装过程很简单：
wget http://www.vanheusden.com/httping/httping-1.4.1.tgz
tar zxvf httping-1.4.1.tgz -C /tmp/
cd /tmp/httping-1.4.1/
make&amp;&amp;make install
默认就安装在/usr下了。如果不想，直接改Makefile去。
然后使用：
httping -options
-g url
-h hostname
-p port
-x host:port（如果是测squid，用-x，不要用-h；和curl的不一样，curl -H指定的是发送的hostname，这个-h是指定给DNS解析的hostname）
-c count
-t timeout
-s statuscode
-S 将时间分开成连接和传输两部分显示
-G GET（默认是HEAD）
-b 在使用了GET的前提下显示传输速度KB/s
-B 同-b，不过使用了压缩
-I useragent
-R referer
-C cookie=*
-l SSL
-U username
-P password
-n a,b 提供给nagios监控用的，当平均响应时间>=a时，返回1；>=b，返回2；默认为0
-N c 提供给nagios监控用的，一切正常返回0，否则只要有失败的就返回c
举例如下：
httping -x 211.151.78.37:80 http://bj.qu114.com/ -SGbs -c 10
Using proxyserver: 211.151.78.37:80
PING bj.qu114.com:80 (http://bj.qu114.com/):
connected to bj.qu114.com:80, seq=0 time=27.00+2945.88=2972.87 ms 200 OK 16KB/s
connected to bj.qu114.com:80, seq=1 time=27.09+2233.38=2260.47 ms 200 OK 17KB/s
connected to bj.qu114.com:80, seq=2 time=26.90+168.70=195.60 ms 200 OK 400KB/s
connected to bj.qu114.com:80, seq=3 time=26.89+2524.52=2551.41 ms 200 OK 15KB/s
connected to bj.qu114.com:80, seq=4 time=26.90+1939.48=1966.37 ms 200 OK 20KB/s
connected to bj.qu114.com:80, seq=5 time=26.79+2085.52=2112.31 ms 200 OK 18KB/s
connected to bj.qu114.com:80, seq=6 time=27.04+1294.78=1321.82 ms 200 OK 32KB/s
connected to bj.qu114.com:80, seq=7 time=26.97+2527.29=2554.26 ms 200 OK 15KB/s
connected to bj.qu114.com:80, seq=8 time=26.88+1498.28=1525.16 ms 200 OK 27KB/s
connected to bj.qu114.com:80, seq=9 time=27.21+1208.70=1235.91 ms 200 OK 34KB/s
--- http://bj.qu114.com/ ping statistics ---
10 connects, 10 ok, 0.00% failed
round-trip min/avg/max = 195.6/1869.6/2972.9 ms
Transfer speed: min/avg/max = 15/59/400 KB


