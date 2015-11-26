---
layout: post
title: awk收发邮件小脚本
date: 2010-03-07
category: bash
tags:
  - awk
---

前两天做监控的小脚本，其实只是采集几个数据，再调用了一个现成的perl大脚本发送出来，最后归入了monitor类别，没好意思放进shell类别里。

今天在CU上翻老帖，看到一个awk实现的收邮件方法。对POP3，对awk，都是很让人开眼界的。在原有基础上，针对性的略加改动，也就完成了SMTP的发邮件awk脚本。这回，可以光明正大的放进shell类别里了~~

收邮件的脚本：
```bash
#!/usr/bin/gawk -f
BEGIN {
    #gawk调用socket的网络通信格式：/inet/<tcp|udp|raw>/<0|local_port>/<remote_host>/<remote_port>
    Service = "/inet/tcp/0/mail.test.com/110"
    #gawk从ksh借鉴来的双向管道
    Service |& getline;
    print;
    print "USER raocl" |& Service
    Service |& getline;
    print;
    print "PASS raocl" |& Service
    Service |& getline;
    print;
    print "LIST" |& Service
    while ((Service |& getline line) > 0 && !(line~/^./) && ++mailCount) print line;
    mailCount--;
    if (mailCount > 0){
        print "RETR "mailCount |& Service
        while ((Service |& getline line) > 0 && !(line~/^./)) print line;
    }
    print "QUIT" |& Service
    close(Service)
}
```
在POP3中，还可以使用TOP n m来获取data的前几行，NOOP来保持与server的连接，DELE来删除邮件。
发邮件的脚本：
```bash
#!/usr/bin/gawk -f
BEGIN {
    Service = "/inet/tcp/0/mail.test.com/25"
    Service |& getline;
    print;
    print "HELO mail.test.com" |& Service
    Service |& getline;
    print;
    print "MAIL FROM: user1@mail.test.com" |& Service
    Service |& getline;
    print;
    print "RCPT TO: user2@mail.test.com" |& Service
    Service |& getline;
    print;
    print "data" |& Service
    
    Service |& getline;
    print;
    print "from: user1@mail.test.com" |& Service
    print "to: <a href="mailto:user2@mail.test.com">user2@mail.test.com</a>" |& Service
    print "date: Fir, 8 Mar 2010 01:11:00 +0800" |& Service
    print "subject: testmail" |& Service
    print "hello, world!" |& Service
    print "." |& Service
    print;
    
    print "QUIT" |& Service
    
    close(Service)
}
```
好了，运行一下吧。

    # ./sendmail.awk && ./getmail.awk
    220 mail.test.com ESMTP jmcs.mta (2.2.2)
    250 mail.test.com
    250 Ok
    250 Ok
    354 End data with <CR><LF>.<CR><LF>
    354 End data with <CR><LF>.<CR><LF>
    +OK scan listing follows
    1 820
    2 1765
    3 1777
    4 1765
    5 768
    +OK Message follows
    Return-Path: <<a href="mailto:user1@mail.test.com">user1@mail.test.com</a>>
    Received: from mail.test.com ([unix socket])
    by mail.21vianet.com (JMessage v2.3) with LMTP; Mon, 08 Mar 2010 01:14:43 +0800
    X-Sieve: CMU Sieve 2.2
    Received: from jmcs.antivirus (localhost.localdomain [127.0.0.1])
    by mail.test.com (jmcs.mta) with SMTP id B7268B2EC4E0
    for <<a href="mailto:user2@mail.test.com">user2@mail.test.com</a>>; Mon,  8 Mar 2010 01:14:43 +0800 (CST)
    Received: from mail.test.com (unknown [218.60.36.39])
    by mail.test.com (jmcs.mta) with SMTP id A38B3B2EC4DE
    for <<a href="mailto:user2@mail.test.com">user2@mail.test.com</a>>; Mon,  8 Mar 2010 01:14:43 +0800 (CST)
    from: <a href="mailto:user1@mail.test.com">user1@mail.test.com</a>
    to: <a href="mailto:user2@mail.test.com">user2@mail.test.com</a>
    date: Fir, 8 Mar 2010 01:11:00 +0800
    subject: testmail
    Message-Id: <<a href="mailto:20100307171443.A38B3B2EC4DE@mail.test.com">20100307171443.A38B3B2EC4DE@mail.test.com</a>>
    hello, world!

就是这样~~报警的话，再继续插入变量处理就行了。在上面的getmail.awk中，其实我和CU上原帖唯一的不同就是他取固定的第7封，而我采用变量取固定的最新一封。这个getmail.awk，下一步可以自动获取信件内容中的IP和alarm-value，然后以cgi的方式显示在网页上（只用一个FF，少开一个TB~自汗一个）

另，awk调用外部变量不方便，也可以采用expect脚本spawn telnet的方式进行自动交互。

其实本来是室友部门部署监控，嫌cacti的报警不像nagios那么醒目了然。我想thold插件既然都能发出mail报警，只要把报警的data变量内容截下来写进一个页面的table里，修改bgcolor显示red不就好了？可是万恶的屏蔽字眼居然把cactiusers.org也给干掉了……没地方下cacti插件了~哭。。。

