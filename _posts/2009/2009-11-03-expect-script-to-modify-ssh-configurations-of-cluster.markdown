---
layout: post
title: expect脚本——批量修改ssh配置
date: 2009-11-03
category: bash
tags: 
  - ssh
---

公司服务器一般通过ssh进行远程管理。以前大家登录的时候，都是随意选内外网IP进入。王总接手后，说这事隐患太大了，必须禁了外网ssh。第一思路，用iptables把外网ssh的包DROP掉；第二思路，用tcpwrapper把sshd的allow写死；第三思路，修改sshd_config，只监听内网请求。

由于一些说不清楚的原因，iptables的办法没法用；而tcpwrapper占用CPU资源较多；所以最后决定用第三种办法。

公司服务器比较多，而且根据随机登录查看的结果，sshd_config内容居然还太不一样～～手工干了一天，改了两组服务器后，终于下定决心要整个全自动脚本出来干活……
目前的办法是这样的：

cat ssh.exp
{% highlight bash %}
#!/usr/bin/expect -f
log_file exp.log
set timeout -1
set ipaddr [lrange $argv 0 0]
for {set i 1} {$i<4} {incr i} {
    spawn ssh $ipaddr
    expect {
        "*password:" break
        "to host" {sleep 2};
        sleep 3
    }
}
send "123456r"
expect "]#"
send "cd /etc/sshr"
send "cp sshd_config sshd_config.`date +%F-%T`.bakr"
send "sed -i /^ListenAddress.*$/d sshd_configr"
send "echo ListenAddress `/sbin/ifconfig eth0|awk '/inet /{print $2}'|awk -F: '{print $2}'` >> sshd_configr"
send "service sshd restartr"
send "exitr"
interact
{% endhighlight %}
cat do.sh
{% highlight bash %}
#!/bin/sh
for ip in `cat ip.lst`
do
    ./ssh.exp $ip > /dev/null 2>&1
done
cat exp.log | grep host | awk '{print $5}'|sort|uniq >> errorip
echo "以下IP无法修改";cat errorip
{% endhighlight %}
