---
layout: post
title: 服务器监控报警小脚本（shell+sendEmail）
date: 2010-03-03
category: monitor
tags:
  - bash
  - perl
---

这种email报警脚本遍地都是，很多用的sendmail、postfix，感觉有些大材小用了；也有些用perl的NET::SMTP和Authen::SASL模块发信的，不过我perl用的不好，老发出些莫名其妙的邮件来（比如if(a>1){print(a);}，最后邮件里的显示的是0.99……）；最后采用sendEmail这个成型的perl程序发信报警，而实时监控部分回归shell，终于完成。

```bash
wget <a href="http://caspian.dotconf.net/menu/Software/SendEmail/sendEmail-v1.56.tar.gz">http://caspian.dotconf.net/menu/Software/SendEmail/sendEmail-v1.56.tar.gz</a>
tar zxvf sendEmail-v1.56.tar.gz
cp sendEmail-v1.56/sendEmail /shell/check/
cat >> check.sh <<EOF

#!/bin/bash

checkmail() {
    /usr/bin/perl ./sendEmail -f userid@mail.com -t oneuserid@mail.com –cc twouserid@mail.com threeuserid@mail.com -u "$subject" -m "$data" -s smtp.mail.com -xu userid -xp password
    sleep 300
}

while true;do
    loadavg=`awk '{print $2}' /proc/loadavg`
    diskuse=`df |awk '/cache/{print $5}'`
    servrun=`netstat -pln|awk -F/ '/:80/{print $NF}'`
    
    ip=`ifconfig|awk '/cast/{print $2}'|awk -F: '{if(NR==1){a=$2}else if(NR==2){b=$2}}END{print b"-"a}'`
    data=`echo -e "ip:$ip\nloadavg/5min:$loadavg\tcacheuse%:$diskuse\tservice:$servrun"`
    diskper=`echo $diskuse|sed 's/%//'`
    
    num=`ps aux|grep check.sh|grep -v grep|wc -l`
    
    if [[ $num > 2 ]];then
        break 2
    fi
    
    if [[ $loadavg > 1.00 ]] &amp;&amp; [[ $diskper > 90 ]];then
        subject="warning-$ip-loadavg-disk"
        checkmail
    else if [[ $loadavg > 1.00 ]];then
        subject="warning-$ip-loadavg"
        checkmail
    else if [[ $diskper > 90 ]];then
        subject="warning-$ip-disk"
        checkmail
    fi
    sleep 60
done

EOF
```
完成，执行sh check.sh &> /dev/null即可。报警邮件如下：

标题：warning-192.168.0.100-10.10.10.10-disk
ip:192.168.0.100-10.10.10.10
loadavg/5min:0.38 cacheuse%:94% service:nginx


