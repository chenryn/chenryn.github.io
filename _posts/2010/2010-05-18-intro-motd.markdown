---
layout: post
title: 服务器登陆欢迎信息~
date: 2010-05-18
category: linux
---

上同事的测试机，发现登陆的时候在显示PS1前还显了一行'Welcome to Cloudex'的欢迎信息，蛮好玩的。
于是去百度一下，原来是设置/etc/issue和/etc/motd文件就可以了。打开/etc/issue，里面已经有两行centos5的信息，先加这里试试，保存退出，重新ssh上服务器，结果还是默认的：
    Connecting to 192.168.0.1:22...
    Connection established.
    Escape character is <a href="mailto:'^@]'">'^@]'</a>.
    Last login: Tue May 18 16:04:38 2010 from 192.168.1.1
    [root@test ~]#
再仔细看看，似乎这个文件得restart后才能生效。
再去修改motd，退出重登陆。还是不行……这就怪了~~~
这事儿过身就忘了，直到今天，看/etc/ssh/sshd_config，正好看到里面有一条PrintMotd no，莫非就是这个！？赶紧改成PrintMotd yes，/etc/init.d/sshd restart;exit，重登陆。果然看到之前卸载motd里的欢迎信息了~
    Last login: Tue May 18 16:04:38 2010 from 192.168.1.2
    haha,I'm Raocl!
    [root@sdl4 ~ 16:04:46]#
OK啦~~

