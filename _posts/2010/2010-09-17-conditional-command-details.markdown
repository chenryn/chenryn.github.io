---
layout: post
theme:
  name: twitter
title: 条件判断命令小细节
date: 2010-09-17
category: bash 
---

服务器上有个定时任务，执行结果输出到out.txt中以便查看，类似下行这样的：

*/5 * * * * /shell/runscript.sh >> /shell/out.txt

runscript.sh中执行script.sh，完成后删除。

/shell目录下的所有文件不定期的通过rsync --delete同步过去。
结果发现如果script在5分钟内无法执行完毕的话，cron会重复执行……
考虑到rsync过来的时候out.txt已经被删除掉了决定在runscript.sh前加上一段[[ -f out.txt ]] && exit
结果发现script一直无法运行了。
想想原来是cron每5分钟都会去生成out.txt，只不过当空闲的时候，这个out.txt是空文件而已。
修改判断为[[ -s out.txt ]] && exit
成功。
其实当文件存在的情况下，shell的条件判断还有很多很多种可能，列表如下：

    -b file            若文件存在且是一个块特殊文件，则为真
    -c file            若文件存在且是一个字符特殊文件，则为真
    -d file            若文件存在且是一个目录，则为真
    -e file            若文件存在，则为真
    -f file            若文件存在且是一个规则文件，则为真
    -g file            若文件存在且设置了SGID位的值，则为真
    -h file            若文件存在且为一个符合链接，则为真
    -k file            若文件存在且设置了"sticky"位的值
    -p file            若文件存在且为一已命名管道，则为真
    -r file            若文件存在且可读，则为真
    -s file            若文件存在且其大小大于零，则为真
    -u file            若文件存在且设置了SUID位，则为真
    -w file            若文件存在且可写，则为真
    -x file            若文件存在且可执行，则为真
    -o file            若文件存在且被有效用户ID所拥有，则为真

