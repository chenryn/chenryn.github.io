---
layout: post
title: shell技巧——getopts
date: 2009-11-04
category: bash
---

在写sh脚本的时候，常常需要运行时输入一些数据。之前已经知道用基本的$*，执行的情况，大概就是$0 $1 $2 $3……
那么，那些系统命令里的参数又是怎么做出来的呢？我们自己的脚本如何搞出来$0-$1的效果呢？这就是getopts的作用了。举例如下：
```bash
#!/bin/bash
echo "OPTIND starts at $OPTIND"
while getopts ":pq:" optname
do
    case "$optname" in
    "p")
        echo "Option $optname is specified"
        ;;
    "q")
        echo "Option $optname has value $OPTARG"
        ;;
    "?")
        echo "Unknown option $OPTARG"
        ;;
    ":")
        echo "No argument value for option $OPTARG"
        ;;
    *)
        # Should not occur
        echo "Unknown error while processing options"
        ;;
    esac
    echo "OPTIND is now $OPTIND"
done
```
在使用getopts命令的时候，shell会自动产生两个变量OPTIND和OPTARG。

OPTIND初始值为1，其含义是下一个待处理的参数的索引。只要存在，getopts命令返回true，所以一般getopts命令使用while循环；

OPTARG是当getopts获取到其期望的参数后存入的位置。而如果不在其期望内，则$optname被设为?并将该意外值存入OPTARG；如果$optname需要拥有具体设置值而实际却没有，则$optname被设为:并将丢失设置值的optname存入OPTARG；

对于$optname，可以用后标:来表示是否需要值；而前标:则表示是否开启静默模式。


