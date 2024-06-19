---
layout: post
theme:
  name: twitter
title: inotify-purge后续分析
date: 2010-11-25
category: linux
tags:
  - inotify
  - bash
  - gnuplot
---

在选定sersync2进行command方式刷新后，需要对诸多域名的更新频率做个简单的分析，以了解编辑的操作习惯，方便选定调整时间、确定文件过期时间等等。

经过测试，早command插件下，sersync输出的是file的全路径。考虑到实际情况是有大量servername和serveralias，运行如下脚本：
```bash
#!/bin/bash
MODIFY_FILE="$1"
MODIFY_DIR=`echo $MODIFY_FILE|awk -F/ '{print $3}'`
MODIFY_URI=`echo $MODIFY_FILE|sed 's/\/backup\/.*.test.com\/htdocs//'`
MODIFY_DOMAIN=`cat servername.list|grep $MODIFY_DIR|awk '{print $2}'`

IPLIST="1.1.1.12
1.1.1.79
1.1.1.87
1.1.1.21
1.1.1.22
1.1.1.23
1.1.1.27
1.1.1.80
"
Time=`date +%Y%m%d`
Username='test.com'
Userkey='test'
Userpass='test.com1234'
MD5=`echo -n "$Time$Username$Userkey$Userpass"|md5sum|awk '{print $1}'`

function cache_purge {
for i in $IPLIST;do
/home/tools/squidclient -p 80 -h $i -m purge "$1"
done
curl -s -G -d "username=${Username}&amp;md5=${MD5}&amp;url_list=$1" http://cs.fastweb.com.cn/interface/push_portal.php
}

for i in `echo $MODIFY_DOMAIN|sed 's/,/ /g'`;do
PURGE_URL="http://$i$MODIFY_URI"
echo "`date +%F-%T` $PURGE_URL" >> purge.log
cache_purge $PURGE_URL
done
```

然后运行如下命令，分别得到html/js/css的每分钟更新量：（有点小瑕疵，即当某分钟html无更新时js和css也无法记录，不过这种概率应该不高）

```bash
cat /home/tools/purge.log |awk -F"[:|-]" '/html/{a[$4":"$5]++}/js/{b[$4":"$5]++}/css/{c[$4":"$5]++}END{for(i in a){print i,a[i],b[i],c[i]}}'|sort
```

得到文件类似如下：

    11:23 28 15
    11:24 10 7
    11:25 224 37 13
    11:26 470 192
    11:27 344 187 1
    11:28 441 77 2
    11:29 419 8

然后创建gnuplot.conf如下：
```tcl
set terminal png xFFEEDD size 2048,512
set output "log.png"
set autoscale
set xdata time
set timefmt "%H:%M"
set format x "%H:%M"
set xtics 10
set mxtics 4
set style data lines
set datafile missing "0"
set xlabel "time per day"
set ylabel "purge"
set title "DPD expires"
set grid
plot "log" using 1:2 title "html/min","log" using 1:3 title "js/min","log" using 1:4 title "css/min"
```

运行 `cat gnuplot.conf|gnuplot` 就得到 log.png 了，如下：

![gnuplot-log](/images/uploads/log.png)
