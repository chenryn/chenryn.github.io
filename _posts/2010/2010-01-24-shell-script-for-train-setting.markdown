---
layout: post
title: CUshell版惊见中国特色脚本
date: 2010-01-24
category: bash
---

58同城：
```bash
#!/bin/bash
#该脚本仅用于58同城网站刷票
#到达目的地
DES="(天水|兰州|西安)"
#刷票url
URL=http://bj.58.com/huochepiao/a1/
OLDMD5=`curl $URL | egrep "$DES" | sed '$d' | md5sum | awk '{print $1}'`
while true; do
    if [ "$OLDMD5" == `curl $URL | egrep "$DES" | sed '$d' | md5sum | awk '{print $1}'` ];then
        sleep 300
    else
        MESSAGE=`curl $URL | egrep "$DES" | sed '$d' | head -n1`
        SEND=`echo $MESSAGE | awk -F">" '{print $3}' | sed -e 's/<.*//'`
        DATE=`echo $SEND | awk -F":" '{print $2}'`
        #判断DATE变量，使其匹配你需要出发的日期
        if [ "$DATE" == "2010-02-08" -o "$DATE" == "2010-02-09" -o "$DATE" == "2010-02-10" -o "$DATE" == "2010-02-11" -o "$DATE" == "2010-02-12" -o "$DATE" == "2010-01-28" ];then
            #输入需要发送信息的命令,飞信或mail等.....,发送的内容为$SEND变量
            /usr/bin/curl -d cdkey=xxxx-xxx-xxxx-xxxxx -d password=xxxxxx -d addserial=xxx -d phone=13000000000 -d message="$SEND:58.com" http://sdkhttp.eucp.b2m.cn/sdkproxy/asynsendsms.action
        fi
        OLDMD5=`curl $URL | egrep "$DES" | sed '$d' | md5sum | awk '{print $1}'`
        sleep 300
    fi
done
```
赶集网：
```bash
#!/bin/bash
#该脚本仅用于赶集网刷票
#到达目的地
DES="(天水|兰州|西安)"
#刷票url
URL=http://bj.ganji.com/piao/sell/
OLDMD5=`curl $URL | egrep "$DES" | md5sum | awk '{print $1}'`
while true; do
    if [ "$OLDMD5" == `curl $URL | egrep "$DES" | md5sum | awk '{print $1}'` ];then
        sleep 300
    else
        MESSAGE=`curl $URL | egrep "$DES" | head -n1`
        SEND=`echo $MESSAGE | awk -F">" '{print $3}' | sed -e 's/<.*//'`
        DATE=`echo $SEND | awk -F":" '{print $2}'`
        #判断DATE变量，使其匹配你需要出发的日期
        if [ "$DATE" == "02-08" -o "$DATE" == "02-09" -o "$DATE" == "02-10" -o "$DATE" == "02-11" -o "$DATE" == "02-12" -o "$DATE" == "01-28" ];then
        #输入需要发送信息的命令,飞信或mail等.....,发送的内容为$SEND变量
        /usr/bin/curl -d cdkey=xxxx-xxx-xxxx-xxxxx -d password=xxxxxx -d addserial=xxx -d phone=13000000000 -d message="$SEND:ganji.com" <a href="http://sdkhttp.eucp.b2m.cn/sdkproxy/asynsendsms.action">http://sdkhttp.eucp.b2m.cn/sdkproxy/asynsendsms.action</a>
        fi
        OLDMD5=`curl $URL | egrep "$DES" | md5sum | awk '{print $1}'`
        sleep 300
    fi
done
```
