---
layout: post
theme:
  name: twitter
title: sscanf用法
date: 2010-04-20
category: C
---

int sscanf(

const char *buffer,

const char *format [,argument ] ...

);
最简单的举例：切割时间

char sztime1[16] = "", sztime2[16] = "";
sscanf("2006:03:18 - 2006:04:18", "%s - %s", sztime1, sztime2);

可是如果时间是"2006:03:18-2006:04:18"，即没有空格时，%s的定义就没法用了。这时候可以使用%[..]来定义，如下

sscanf("2006:03:18-2006:04:18", "%[0-9,:]-%[0-9,:]", sztime1, sztime2);

%[]的用法，类似正则表达式，可以采用[a-z]这样的匹配；可以采用[^a-z]这样的排除匹配；还可以采用*[a-z]这样的匹配过滤。举例如下：

const  char sourceStr[] = "hello, world";

char buf[10] = {0};

sscanf(sourceStr, "%*s%s", buf);

执行结果就是过滤了hello，打印出world~~


