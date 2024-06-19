---
layout: post
theme:
  name: twitter
title: nrpe编译小问题
date: 2010-11-10
category: monitor
tags:
  - nagios
---

一般情况下，在nagios被监控端安装nrpe和nagios-plugins的工作相当的简单重复。不过这次碰上一个诡异问题。

设备是RedHat AS4，在./configure时，报出如下错误：

checking for C compiler default output file name... a.out

checking whether the C compiler works... configure: error: cannot run C compiled programs.

If you meant to cross compile, use `--host'.

See `config.log' for more details.

dmesg信息输出如下：

a.out[4272]: segfault at 00000000bffff770 rip 0000000000400456 rsp 00000000bffff770 error 4

起先以为是内存问题，检查boot.log没问题；然后又yum reinstall了gcc，问题依旧。

在config.log中慢慢翻，赫然看到如下一段：

configure:1782: checking for C compiler version

configure:1785: gcc --version </dev/null >&amp;5

gcc32 (GCC) 3.2.3 20030502 (Red Hat Linux 3.2.3-47.3)

Copyright (C) 2002 Free Software Foundation, Inc.

This is free software; see the source for copying conditions.  There is NO

warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

&nbsp;

configure:1788: $? = 0

configure:1790: gcc -v </dev/null >&amp;5

Reading specs from /usr/lib/gcc-lib/x86_64-redhat-linux/3.2.3/specs

Configured with: ../configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info --enable-shared --enable-threads=posix --disable-checking --with-system-zlib --enable-__cxa_atexit --enable-languages=c,c++ --disable-libgcj --host=x86_64-redhat-linux

Thread model: posix

gcc version 3.2.3 20030502 (Red Hat Linux 3.2.3-47.3)

configure:1793: $? = 0

configure:1795: gcc -V </dev/null >&amp;5

gcc32: argument to `-V' is missing

configure:1798: $? = 1

……

## ----------------- ##

## Output variables. ##

## ----------------- ##

……

host='x86_64-unknown-linux-gnu'

真相大白！因为./configure检查出来的hostname和gcc编译时的hostname不一致！

改用./configure --host=x86_64-redhat-linux，编译顺利通过~~~
