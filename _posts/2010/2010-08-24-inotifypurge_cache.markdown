---
layout: post
theme:
  name: twitter
title: inotify+purge_cache
date: 2010-08-24
category: linux
tags:
  - inotify
  - bash
---

linux内核从2.6.13开始，加入了inotify特性。对目录、文件的各种修改，都会发出inotify信号。包括
    IN_ACCESS
    IN_MODIFY
    IN_ATTRIB
    IN_CLOSE_WRITE
    IN_CLOSE_NOWRITE
    IN_OPEN
    IN_MOVED_FROM
    IN_MOVED_TO
    IN_CREATE
    IN_DELETE
    IN_DELETE_SELF
    IN_MOVE_SELF
    IN_UNMOUNT
    IN_CLOSE
    IN_MOVE
目前最常见的inotify应用，就是和rsync配合进行实时同步。
而对web发布路径进行inotify监听的话，可以实时PURGE掉前端cache，保证网民访问的实效性。内容更新周期不固定的一些网站，大可以设定长一些的expires（也不要太长，不然浏览器端本身的缓存影响比较大），然后通过inotify监听来强制控制缓存时间，应该是比较有效果的。
最早的思路，先用perl的Linux::Inotify模块watch目录，read出每次event的name；再用IO::Socket模块向squid发送"PURGE $url HTTP/1.0\n\n"请求，最后用WWW::Curl::Form模块POST数据到CDN的刷新接口。洋洋洒洒好几十行后，发现利用inotify-tools、curl、squidclient等现成的工具，写成的shell脚本更加简单而且方便。
先修改squid.conf，添加web服务器ip的purge权限，重读配置；
在web服务器上，从sourceforge下载inotify-tools源码编译：wget http://github.com/downloads/rvoicilas/inotify-tools/inotify-tools-3.14.tar.gz &amp;&amp; tar zxf inotify-tools-3.14.tar.gz &amp;&amp; cd inotify-tools-3.14 &amp;&amp; ./configure --prefix=/usr &amp;&amp; make &amp;&amp; make install
从squid上scp /usr/local/squid/bin/squidclient 到web服务器上；
要是没有curl的话，yum install一个。
最后创建inotify-purge.sh脚本如下：
```bash
#!/bin/bash
WEB_DIR=/path/to/example
IPLIST="1.2.3.4
1.2.3.5
1.2.3.6
1.2.3.7
1.2.3.8
"

inotifywait -mrq --format '%f' -e modify,delete,create,move ${WEB_DIR} | while read file
do
    PURGE_URL=`echo "http://dvs.china.com/$file"`
    for i in $IPLIST;do
        /home/tools/squidclient -p 80 -h $i -m purge "$PURGE_URL"
    done
    curl -s -d "username=test&amp;password=123456&amp;type=1&amp;url=$PURGE_URL" http://pushwt.dnion.com/cdnUrlPush.do
done
```

