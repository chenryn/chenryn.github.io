---
layout: post
title: at命令
date: 2010-04-26
category: bash
---

经常使用crontab做定时任务。不过偶然碰到只需要半夜执行一次就够了的时候，还用crontab的话，第二天还得记得上去删除掉任务。就比较麻烦了——尤其是我记忆力不太好~~
好在发现了at命令：

首先启动at服务/etc/init.d/atd start

然后at -f test.sh -v 17:10

系统返回

    job 1 at 2010-04-27 17:10

然后at -f ptest.sh  2:00 july 11
系统返回

    job 2 at 2010-07-11 02:00

用atq查看任务队列

    2 2010-07-11 02:00 a root
    1 2010-04-27 16:10 a root

用at -c [job号]查看任务内容

用atrm [job号]删除任务
