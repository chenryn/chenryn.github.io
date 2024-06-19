---
layout: post
theme:
  name: twitter
title: squid 自动配置脚本
date: 2009-11-03
category: devops
tags:
  - squid
  - web
  - bash
---

公司刚重新规定了squid服务的标准配置。以后，客户的配置要求，统一安排。这样，除了一些有特殊要求（比如加密／防盗链等）的以外，普通客户就可以逐步实现简洁明了的规范化自动化配置。

目前squid的初始化准备还在慢慢进行中，趁有点空闲，先把自动化配置脚本搞出来。

主程序do.sh如下：

```bash
    #!/bin/bash
    if [ "$#" -ne 2 ];then
    echo "Usage: ./do.sh [command][customer]"
    echo "For example:./do.sh add abc"
    echo "                            ./do.sh del abc"
    exit 1
    elif [ ! -s ip.lst -a -e ip.lst ];then
    echo "No server in ip.lst"
    exit 1
    fi
    for ip in `cat ip.lst`;do
    ping -c 5 $ip
    expect ssh.exp $ip $1 $2
    done
```

ssh.exp如下：

```tcl
    #!/usr/bin/expect -f
    log_file exp.log
    set ipaddr [lindex $argv 0]
    set command [lindex $argv 1]
    set custom [lindex $argv 2]
    spawn scp /squid.config/$custom /rt/conf.sh $ipaddr:/root/
    for {} 1 {} {
      expect {
        eof
        break
        "(yes/no)?" {send "yesr"}
        "assword:" {send "123456r"}
      }
    }
    spawn ssh root@$ipaddr bash conf.sh $command $custom
    for {} 1 {} {
      expect {
        eof
        break
        "(yes/no)?" {send "yesr"}
        "assword:" {send "123456r"}
      }
    }
```

conf.sh如下：

```bash
    #!/bin/bash
    NR=$(cat $2|wc -l)
    CONF=/etc/squid.conf
    if [ "$1" == "add" ];then
        sed -i "/config/r $2" $CONF
    elif [ "$1" == "del" ];then
        CFNR=`sed -n -e /$2/= $CONF`
        BEGINNR=`echo $CFNR|awk '{print $1}'`
        ENDNR=`expr $BEGINNR + $NR`
        sed -i "/$BEGINNR/,/$ENDNR/d" $CONF
        rm -f "$2"*
    else
        echo "Use add or del please!"
    fi
    killall -9 squid
    ulimit -HSn 655360
    /sbin/squid -s
```

然后我们模拟一个叫做abc的客户来测试CDN了。那么我只要在/squid.config/下创建一个叫做abc的文本，内容是针对性的配置部分字段，假设如下：

```squid
    #abc
    refresh_pattern -i http://www.abc.com/.*.(jpg|gif|js|css|swf|xml)$ 1440 50% 4320 ignore-reload
    acl abc url_regex -i ^http://www.abc.com/.*.(html|do|jsp|asp|aspx|axd|asmx)
    cache deny abc
```

然后运行./do.sh add abc，就可以自动在ip.lst里所有的服务器的squid.conf中的“#config”字段下面，添上abc的配置文件了。

过一段时间，要是abc这个客户流失了，就运行./do.sh del abc就行了。

之前的思路，局限在一句句往配置文件里插句子。于是用下面这个办法

```bash
    sed -i s/"config"/{
    a"……"/
    a"……"/
    a"……"/
    }
    squid.conf
```

而这样配置句段的顺序就反过来了，还得用 `sed -n "1!G;h;$!d"` 命令倒序读取——最开始用cat命令，结果cat在读取abc这个文件的时候会自动把空格前后的内容分段读出，于是改用sed。至于倒序之后，再怎么插入，就没有研究了。因为当时我发现了可以直接将文件a插入文件b的方法～～

del的时候，其实在操作上还有一个办法。就是每次的配置不单以#abc开头，还用一个#abcEND结尾。这样，ENDNR就不用计算，直接取echo $CFNR|awk '{print $NF}'就行了。

说到这个CFNR，让人很郁闷的一点是，这个sed -n -e出来的几个数字，我本意是作一个数组的，但怎么试验，shell都把这一串数字存在${CFNR[0]}一个元素里……数组到底怎么输入，还得研究～～

