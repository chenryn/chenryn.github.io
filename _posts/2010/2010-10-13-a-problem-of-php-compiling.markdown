---
layout: post
title: php编译小问题
date: 2010-10-13
category: php
---

昨天应用调整，尝试将服务器上的php降级，从5.3.0降到5.2.10，在编译时爆出如下错误提示：

./.libs/libgd.so: undefined reference to `png_check_sig'
collect2: ld returned 1 exit status

因为之前有过安装，所以可以确认libpng是已经存在的。百度后看到如下说法：

libpng-1.4.0源码中的libpng-1.4.0.txt有说明,已经取消了png_check_sig这个函数,改用png_sig_cmp代替.自从libpng-0.90就已经反对使用png_check_sig函数了

所以修改php源码中的ext/gd/libgd/gd_png.c如下：

-   if (!png_check_sig (sig, 8)) { /* bad signature */
+ if (png_sig_cmp (sig, 0, 8)) { /* bad signature */

保存后重新编译，顺利通过。
