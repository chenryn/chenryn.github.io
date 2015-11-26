---
layout: post
title: 网络监控与/proc/net/tcp文件
date: 2010-07-28
category: monitor
tags:
  - procfs
---

nagios自带的check_antp太过简约，除了状态统计输出外，什么参数都不提供。在面对不同应用服务器时，报警就成了很大问题。于是决定自己写一个check脚本。作脚本运行，与命令操作时一个不同，就是要考虑一下效率问题。在高并发的机器上定期运行netstat -ant命令去统计，显然不太合适，可以直接从proc系统中取数据，这就快多了。

先介绍/proc/net/tcp文件，这里记录的是ipv4下所有tcp连接的情况，包括下列数值：

    sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
    0: 00000000:3241 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 22714864 1 ffff88004f918740 750 0 0 2 -1

最主要的，就是local_address本地地址:端口、rem_address远程地址:端口、st连接状态。

注1：文件中都是用的16进制，所以HTTP的80端口记录为0050。    
注2：状态码对应如下

    00  "ERROR_STATUS",
    01  "TCP_ESTABLISHED",
    02  "TCP_SYN_SENT",
    03  "TCP_SYN_RECV",
    04  "TCP_FIN_WAIT1",
    05  "TCP_FIN_WAIT2",
    06  "TCP_TIME_WAIT",
    07  "TCP_CLOSE",
    08  "TCP_CLOSE_WAIT",
    09  "TCP_LAST_ACK",
    0A  "TCP_LISTEN",
    0B  "TCP_CLOSING",

然后介绍nrpe的check脚本。脚本不管怎么写都行，对于nagios服务器端来说，它除了接受脚本的输出结果外，只认脚本运行的退出值（测试时可以运行后用echo $?看），包括OK的exit 0、WARNING的exit 1、CRITICAL的exit 2、未知的exit 3。

最后一个简单的检查http端口连接数的脚本如下：
```bash
#!/bin/bash
#Written by Gemmy.Rao
#Email to: <a href="mailto:chenlin.rao@bj.china.com">chenlin.rao@bj.china.com</a>
#Version 0.2
#CHANGES
#Add -p option for checking other service's port

#Init
PORT=80
WARNING=5000
CRITICAL=20000

#get options
while getopts "w:c:p:hs" OPT;do
    case $OPT in
    w)
        WARNING=${OPTARG}
        ;;
    c)
        CRITICAL=${OPTARG}
        ;;
    p)
        PORT=${OPTARG}
        #转换各端口的十进制成十六进制
        PORT_16=`echo ${PORT}|awk -F, '{for(i=1;i<=NF;i++)printf "|%.4X",$i}'|sed 's/|//'`
        ;;
    h)
        echo "Usage: $0 -w 500 -c 2000 -p 80,8081 -s"
        exit 0
        ;;
    s)
        SILENT=1
        ;;
    *)
        echo "Usage: $0 -w 500 -c 2000 -p 80,8081"
        exit 0
        ;;
    esac
done

#经过time测试，取值速度netstat > awk '//{a++}END{print a}' > cat|grep|wc > cat|awk|wc，在2w连接下，netstat要20s，最快的方式不到5s（一般nagios到10s就该直接报timeout了）
PORT_CONN=`cat /proc/net/tcp*|awk '$2~/:('$PORT_16')$/'|wc -l`

if [[ "$SILENT" == 1 ]];then
    [[ -d /usr/local/nagios ]] || mkdir -p /usr/local/nagios
    echo "Silent log write OK | Port ${PORT}=${PORT_CONN};${WARNING};${CRITICAL};0;0"
    echo -en "`date`t$PORT_CONNn" >> /usr/local/nagios/conn.log
    exit 0
elif [[ "$PORT_CONN" -lt "$WARNING" ]];then
    echo "Port $PORT connection OK for $PORT_CONN. | Port ${PORT}=${PORT_CONN};${WARNING};${CRITICAL};0;0"
    exit 0
elif [[ "$PORT_CONN" -gt "$CRITICAL" ]];then
    echo "Port $PORT connection critical for $PORT_CONN!! | Port ${PORT}=${PORT_CONN};${WARNING};${CRITICAL};0;0"
    exit 2
else
    echo "Port $PORT connection warning for $PORT_CONN! | Port ${PORT}=${PORT_CONN};${WARNING};${CRITICAL};0;0"
    exit 1
fi
```

之后有必要的话，可以再取$4去统计st。
