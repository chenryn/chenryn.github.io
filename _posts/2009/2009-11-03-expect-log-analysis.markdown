---
layout: post
title: expect日志分析
date: 2009-11-03
category: bash
tags:
  - expect
---

接着上次expect脚本那事儿往下走。
由于不同服务的管理方法不同，上次关闭了ssh的外网登录以后，各地不断有服务器报出这样那样的问题。主管一发狠：“全面检查！”
在检查中，还真发现不少问题。最突出的就是很多本应该上传到中心服务器的日志居然一直留在本机没动弹！时不时发作出来，就撑爆了根分区——这当然有分区规划不合理的问题。但在线业务，磁盘划分修改起来就不是那么方便了。于是退而求其次，定期监控日志文件大小吧。这回expect只要du
-sh一下就行了，方便的很。问题在下一步的分析。
摘举exp.log中一次循环的执行结果如下：
```bash
The authenticity of host '1.2.3.4 (1.2.3.4)' can't be established.
RSA key fingerprint is
bb:d5:81:e1:84:09:c5:32:f6:fb:e1:b3:d3:de:c3:53.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '1.2.3.4' (RSA) to the list of known hosts.
root@1.2.3.4's password:
4.0K /home/apache2/logs/access_log
```
第一步，是用如下脚本，可以做到提取日志达到50M大小的服务器IP。
```bash
#!/bin/bash
nk=`sed -n -e "/50M/=" exp.log`
nnk=`expr $nk - 1`
sed -n "$nnk"p"" exp.log|awk -F"'" '{print $1}'|awk -F"@" '{print $2}'
```
但问题是：如果同时有两台到50M呢？或者在运行到它时，已经到50M以上呢？
于是我想，以ls -sh显示大小，人眼好看，电脑不好认啊。如果用du -b，那大小相同的几率就应该小很多很多了。然后定一个阀值，进行比较循环就可以了。
最后脚本如下：
```bash
#!/bin/bash
for ip in `cat ip.lst`
do
./ssh.exp $ip > /dev/null 2&>1
done
bs=400
size=`grep access exp.log | awk '{if ($1&gt;'"$bs"'){print $1}}'`
for so in $size
do
nk=`sed -n -e "/$so/=" exp.log`
nnk=`expr $nk - 1`
sed -n "$nnk"p"" exp.log | awk -F"'" '{print $1}'|awk -F@ '{print $2}'
done
```
#本来想用sed 'N;s/n//g' exp.log来合并行尾，省得调行号，但exp日志的格式因为ssh登录的提示信息不一而无法统一，只能放弃。
试验性的在ip.lst中输入了15个IP，运行结果显示出来了两个。成功。

