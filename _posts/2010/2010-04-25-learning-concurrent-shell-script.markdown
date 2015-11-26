---
layout: post
title: shell并发脚本学习
date: 2010-04-25
category: bash
---

在CU上看到的老帖子，创建并发程序的shell。个人觉得非常经典，贴回来好好学习使用。用（）包围的是我写的学习笔记，#的是原帖注释：

```bash
#!/usr/bin/ksh（自然我得把这里改成bash）
# SCRIPT: ptest.sh
# AUTHOR: Ray001（呃，这些也是要学习滴，版权意识嘛~）
# DATE: 2008/10/03
# REV: 2.0
# For STUDY
# PURPOSE:
# 实现进程并发，提高执行效率，同时能记录每个执行失败的子进程信息

#定义并发进程数量
PARALLEL=3
#定义临时管道文件名（我为这个定义想了好久，不知道$$.是什么特殊变量；后来实际上测试机一实验才发现把事情想复杂了……这就是以“脚本pid+.fifo”组成的字符串而已。完全可以改写成其他样子。
TMPFILE=$$.fifo
#定义导出配置文件全路径名（其实我个人很诧异为什么这里要定义到家目录去，这样在touch ptest.cfg的时候多麻烦呀）
CMD_CFG=$HOME/cfg/ptest.cfg
#定义失败标识文件
FAILURE_FLAG=failure.log

####################### 函数定义 ########################
# 中断时kill子进程（学习重点一：kill -9 0——杀死脚本自己及衍生出来的子进程，嗯，全家自杀）
function trap_exit
{
    kill -9 0
}
# 通用执行函数
exec_cmd()
{
    # 此处为实际需要执行的命令，本例中用sleep做示例
    sleep ${1}
    if [ $? -ne 0 ]
    then
        echo "命令执行失败"
    return 1
fi
}

####################### 主程序 ########################
#（学习重点二：当信号为1、2、3、15时，执行''中的命令，即调用trap_exit函数自杀，然后退出该shell并返回信号2——把0、1留给后面用）
trap 'trap_exit; exit 2' 1 2 3 15

#清理失败标识文件
rm -f  ${FAILURE_FLAG}

#为并发进程创建相应个数的占位（其实这个定义不绝对正确有效，比如占了十个位，但cfg中只有7个参数传递，这个脚本就只有7个并发，不过这是小节，无关大雅~）
#（创建命名管道）
mkfifo $TMPFILE
#（学习重点三：为命名管道指定文件标识符为4，<>分别是输入和输出，即绑定了该管道的输入输出都在4这个文件标识符上！）
exec 4<>$TMPFILE
#(删除管道文件，不知道这步是为什么，目前只能猜测是担心程序运行时该文件被其他人或者程序误用吧？)
rm -f $TMPFILE
#（用{}和用()的区别在shell是否会衍生子进程。let命令用以变量运算。这一段给文件标识符输入了几个回车。）
#（不知道这几个回车和“并发占位”什么关系。找了很久，没发现？？目前猜测是管道的流处理所以每个子进程用一行）
{
    count=$PARALLEL
    while [ $count -gt 0 ]
    do
        echo
        let count=$count-1
    done
} >& 4

#从任务列表 seq 中按次序获取每一个任务
#（从家目录下那个cfg文件中读取sleep的时间）
while read SEC
do
    #（从标识符中读取回车？不懂，还是管道和子进程的问题……）
    read <& 4
    #（后台执行主程序命令或者输出错误日志，完成后清空标识符）
    (  exec_cmd ${SEC} || echo ${SEC}>>${FAILURE_FLAG} ; echo >&amp;4 ) &
done<$CMD_CFG
#（等待子进程结果返回值）
wait
#（关闭文件标识符4）
exec 4>&-

#并发进程结束后判断是否全部成功
if [ -f ${FAILURE_FLAG} ]
then
    exit 1
else
    exit 0
fi
```

