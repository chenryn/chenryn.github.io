---
layout: post
title: login-shell的更改
date: 2010-07-06
category: linux
---

之前用ports把BSD系统的login-shell改成bash后，今天又打算改回csh去。不料重新chsh -s /bin/csh后，却弹出如下错误提示：

    chsh: entry inconsistent
    chsh: pw_copy: Invalid argument

很诡异的提示~然后直接运行chsh修改SHELL；修改/etc/passwd和/etc/master.passwd中的/usr/local/bin/bash为/bin/csh；退出重登录，还是bash没变……

经过谷大婶的帮助，发现原来在login的时候，并不是读取/etc/master.passwd来决定login-shell，而是会去读取/etc/pwd.db和/etc/spwd.db。只需要运行如下命令更新这两个db文件就可以了：

    pwd_mkdb /etc/master.passwd

试验一下，果然ok了~~

