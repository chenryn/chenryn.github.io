---
layout: post
title: 用 systemtap 调试 kmsg dump 
category: monitor
tags:
  - systemtap
---

google 之前推出了一个 netoops 的 patch，可以让 linux kernel 在崩溃的时候通过 udp 协议把信息发送到远端主机上。我之前在 CentOS6.2 的内核上做过测试，详细做法可以参见淘宝内核组 wiki 的[编译使用淘宝内核](http://kernel.taobao.org/index.php/Documents/Kernel_build)和 [netoops 使用指南](kernel.taobao.org/index.php/Documents/Kernel_netoops_howto)。唯一有区别的地方就是淘宝使用的 RedHat6 的内核在 CentOS6 上有签名问题，需要自己从 CentOS 官网 ftp 下载 src.rpm 来用 —— 当然如果要自己搞定编译那步，少不了就要自己修改 config-genaric 和 kernel.spc 文件了。

昨天同事升级修改到 CentOS6.3 内核( 2.6.32.220 -> 2.6.32.279 )上。结果发现修改冲突代码编译通过后，再使用 soft dump 方式测试，远端主机 nc 收不到结果了。

稍微 grep 一下代码，发现是在 `kernel/printk.c` 里定义 `void kmsg_dump()` 的。好了，使用 systemtap 来检查这里： 

```c
    stap -ve 'probe kernel.function("kmsg_dump"){printf("%s\n",$$vars$$)}'
```

结果发现在 soft dump 的时候有输出，也就是说调用了 `kmsg_dump()`。

比较 2.6.32.220 和 2.6.32.279 的代码，发现在 `kmsg_dump()` 里，新内核多了一点判断，如果reason 低于 `KERNEL_OOPS` 而且没有设置 `always_kmsg_dump` 变量，那么直接返回不再 `dumper->dump()` 了。

```c
1546    if ((reason > KMSG_DUMP_OOPS) && !always_kmsg_dump)
1547            return; 
```

我们验证一下是不是这个原因：

```c
    stap -gve 'probe kernel.statement("*@kernel/printk.c:1548")  { printf("%s\n",$$parms$$) }'
```

显然测试的时候 reason 是 `KERNEL_SOFT`，这个是不好调的，那么我们可以调整这个变量，找了一下没发现这个可以在 sysctl 什么的里面，所以继续用 systemtap 搞定：

```c
    stap -gve 'probe kernel.statement("*@kernel/printk.c:1545")  { $always_kmsg_dump=1; printf("%d",$always_kmsg_dump); printf("%s\n",$$parms$$) }'
```

果然搞定。
