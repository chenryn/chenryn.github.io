---
layout: post
title: bc命令及其他
date: 2010-08-13
category: bash
---

在写check_if_flow.sh的时候，因为要比较的值太多，几个网卡，每个都分进出、然后分w和c。如果直接if判断大小，会写的无比庞大……于是想到根据比较结果先输出一个变量，大就是1，小就是0，类似这种。

于是找到了bc命令，最终结果如下：

[root@test ~]# echo "1.13 > 1.2"|bc
0
[root@test ~]# echo "1.13 < 1.2"|bc
1
bc支持+-*/%^=!><各种运算，还能通过scale指定小数点后几位；
还能任意转换数字的进制，如下：

[root@test ~]# echo 'obase=10; ibase=16; 1E79' | bc
7801

相比之前脚本里用的awk要灵活（就是必须大写）。awk从十进制变十六进制很容易，变回去就难了……得用上函数才行：

[root@test ~]# echo '1E79'|awk '{printf "%s",strtonum("0x"$1)}'
7801

而shell相反，从十六进制变十进制很容易，反过来去难……

[root@test ~]# echo $[16#1e79]
7801

ksh中可以指定typeset -i，bash没找到~所以只能把别的进制改成10进制

[root@test ~]# ksh
# typeset -i16 num=7801
# echo $num
16#1e79

