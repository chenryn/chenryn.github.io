---
layout: post
theme:
  name: twitter
title: ftp中的软连接问题
date: 2010-11-22
category: linux
---

数据临时迁移，为了尽量不影响业务，创建了一个软连接。不料pureftpd出了一点小问题。

当ln -s /text /www/text的时候，如果pureftpd.passwd中指定的是/www/text，访问没有问题；如果是/www的话，再cd text会出问题。

搞怪的是，text1出的报错是Too many levels of symbolic links，而text2出的报错是No such file or directory……

进pureftpd的src里看./configure --help，看到如下一行：

--with-virtualchroot    Enable the ability to follow symlinks outside a chroot jail

以前的编译，都只用了--with-everything       Build a big server with almost everything

看来almost里还真就不包括virtualchroot……

重新编译pureftpd，加上了virtualchroot参数。然后cp原ftp的pdb过来，启动一试，OK~
