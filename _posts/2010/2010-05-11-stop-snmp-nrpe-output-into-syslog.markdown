---
layout: post
title: 关闭snmp和nrpe的syslog正常输出
date: 2010-05-11
category: linux
tags:
  - snmp
  - nagios
  - syslog
---

默认安装启动的snmp，会把日志记录在系统日志/var/log/messages里。

特别郁闷的一点是，哪怕一次snmp连接请求，它也要记录上好几句。。。系统日志呀，多少关键信息，就这样湮没在snmp的刷屏里了……

于是决定关掉这些输出。找了找，snmp.conf里好像没有关于log-file的配置，ps看进程，/usr/sbin/snmpd后面跟了长长一大串的options，于是觉得可以看看--help和/etc/init.d/里的启动脚本。

果然看到-L参数，而进程中启动的真是Ls：facility:  log to syslog (via the specified facility)！！

指定这部分option（即Ls）为LS 2，就可以了！

而/etc/init.d/snmpd中，这部分定义如下：
```bash
if [ -e /etc/snmp/snmpd.options ]; then
    . /etc/snmp/snmpd.options
else
    OPTIONS="-Lsd -Lf /dev/null -p /var/run/snmpd.pid -a"
fi
```
可见/etc/snmp/snmpd.options优先级比OPTIONS高，而且修改单独文件也比修改系统启动脚本放心些。
```bash
cat > /etc/snmp/snmpd.options <<EOF
OPTIONS="-LS 2 d -Lf /dev/null -p /var/run/snmpd.pid -a"
EOF
```
/etc/init.d/snmpd restart，等等再看，messages里果然没有snmp的刷屏了~~
（注：不同版本的OS启动脚本不同，请自行参考。至少我手头的服务器上就还有在/etc/sysconfig/snmpd.options里的，且须写成Ls而不是LS）

<hr />

然后是nrpe，这也是个刷屏的高手，而且处理起来比snmp还麻烦。因为在nrpe.cfg中，同样没有关于log_file的记录，也没有单独的启动options，因为它是交给xinetd去管理的。

xinetd呀，听着就让我动手的胆子小了不少~~小心着看吧

xinetd --help，呃，压根没输出；

/etc/init.d/xinetd，除了LANG基本没什么定义……

再进/etc/xinetd.d/，赫然发现一个文件叫nrpe！赶紧打开一看，有一条“log_on_failure  += USERID”，改成“log_on_failure  =”，保存退出，重启观察，messages里还是出现新nrpe的条目，失败了……

等等，之前为什么是+=呢？返回上层目录，看/etc/xinetd.conf，原来有“Define general logging characteristics”，默认的日志记录选项，包括log_on_failure/log_on_success和log_type。嗯，看来就是log_type了！

vi /etc/xinetd.d/nrpe，插入log_type SYSLOG daemon info……当然是不行的。百度一下xinetd文档，原来这里有七个等级，看样子应该是从高到低：emerg，alert，crit，err，warning，notice，info，debug。我就改个warning看看吧，不行！alert，还不行！！

发怒了，用emerg——电脑铛铛作响，原来emerg不单记录syslog，还强制显示在tty上…（估计是因为nrpe记录都是start/stop，算起来都是最高级别的动作吧）…就xinetd这速度，都搞的没法干活了~~摸索着捣鼓回原状，继续研究吧~

log_type除了syslog，还有file soft hard方式 ，单独记录。那我输出到空不就行了？于是写成log_type = /dev/null，重启报错：“wrong number of arguments [file=/etc/xinetd.d/nrpe] [line=13]”。文档明确说了soft和hard是可以在不写的情况下默认为5MB 5.05MB的，那只能是file写的格式不对了。

改成log_type = file /dev/null，重启。等呀等呀，五分钟过去了，messages里还是没有nrpe的记录，成功了！

