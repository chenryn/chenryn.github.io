---
layout: post
theme:
  name: twitter
title: ubuntu 9.10下linuxqq经常挂掉的解决方案
date: 2010-01-30
category: linux
---

ubuntu 9.10下linuxqq（官方的QQ，八百年不更新的那个了）

sudo vim /usr/bin/qq
增加
```bash
#!/bin/sh
export GDK_NATIVE_WINDOWS=true
cd /usr/share/tencent/qq/
./qq
```
经试验正确无误。。。linuxqq不再挂。。。五四陈科学院小道报道

原创文章如转载，请注明：转载自五四陈科学院[<a href="http://www.54chen.com]/">http://www.54chen.com]</a>
本文链接: 
<a href="http://www.54chen.com/uncategorized/ubuntu-910-hangs-under-linuxqq-regular-solution.html">http://www.54chen.com/uncategorized/ubuntu-910-hangs-under-linuxqq-regular-solution.html</a>
