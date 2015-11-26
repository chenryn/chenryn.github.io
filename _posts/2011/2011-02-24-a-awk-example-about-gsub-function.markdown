---
layout: post
title: awk一例
date: 2011-02-24
category: bash
tags:
  - awk
---

一个小需求，某目录下有五万多个模板文件，其中大概两万个是链接文件。当碰到如下情况：
lrwxrwxrwx  1 nobody nobody       59 Dec 27 15:06 10000053.mod -> /var/www/html/category/model/10000050.mod
就需要创建同名的另一个模板文件10000053.wap文件，指向10000050.wap。
怎么做？
我用了如下命令：
```bash
ls -l /var/www/html/category/model | awk '$1~/^l/ && $9~ /mod$/ {gsub(/mod$/,"wap",$9);gsub(/mod$/,"wap",$NF);system("rm -f "$9" && ln -s "$NF" "$9)}'```
不过从效果来看，使用gsub函数后速度慢了不少，这5万个文件花了几分钟。

<hr>

另，在CU上看到另一个文件操作的shell考题，据说是腾讯的题。修改某目录下（含子目录）所有.shell文件为.sh。我的思路和上头的类似。不过在微博上看到一个超级不错的写法，记录一下：
```bashrename .shell .sh `find ./ -name *.shell````
