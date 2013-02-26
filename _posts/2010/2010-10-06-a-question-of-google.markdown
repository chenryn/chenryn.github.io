---
layout: post
title: google校招笔试题
date: 2010-10-06
---

刚在CU看到传说中的一道google2011年校招笔试题，如下：

现在北京有一套房子，价格200万，假设房价每年上涨 10%，一个软件工程师每年固定能赚40万。如果他想买这套房子，不贷 款，不涨工资，没有其他收入，每年不吃不喝不消费，那么他需要几年才能攒够钱买这套房子？
A, 5年
B, 7年
C, 8年
D, 9年
E, 永远买不起

最简单的思路，算算每年的房价和攒下的工资总数，最多到房价超过400万的时候就不用算了，因为那时候10%就大于工资了……

#!/bin/bash
fangzi=200
gongzi=40
while true
do
fangzi_new=`echo $fangzi|awk '{print $1*1.1}'`
gongzi_new=`echo $gongzi|awk '{print $1+40}'`
echo -ne "$fangzi_new\t$gongzi_new\n"
fangzi=`echo $fangzi_new`
gongzi=`echo $gongzi_new`
sleep 5
done
运行结果如下：
220    80
242    120
266.2    160
292.82    200
322.102    240
354.312    280
389.743    320
428.717    360

完蛋了，永远买不起……

不过有人提供另一种思路，如果先买40万的房子，第二年卖出，然后买84万的……

#!/bin/bash
fangzi=200
gongzi=40
while true
do
fangzi_new=`echo $fangzi|awk '{print $1*1.1}'`
gongzi_new=`echo $gongzi|awk '{print $1*1.1+40}'`
echo -ne "$fangzi_new\t$gongzi_new\n"
fangzi=`echo $fangzi_new`
gongzi=`echo $gongzi_new`
sleep 5
done
运行结果如下：
220    84
242    132.4
266.2    185.64
292.82    244.204
322.102    308.624
354.312    379.486

第七年就搞定了！！而第七年的工资总数是280万，倒房能倒到379.5万！！

唉~~
