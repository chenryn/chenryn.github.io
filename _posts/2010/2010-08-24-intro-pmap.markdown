---
layout: post
theme:
  name: twitter
title: pmap命令
date: 2010-08-24
category: linux
---

继pgrep之后，又发现一个pmap命令，有些不错的小作用~
比方说，用pgrep java得出pid后，用pmap $pid，得出输出结果如下：

    23792:   /usr/java/jdk1.5.0_14/bin/java -Djava.util.logging.manager=com.caucho.log.LogManagerImpl -Djava.system.class.loader=com.caucho.loader.SystemClassLoader -Djavax.management.builder.initial=com.caucho.jmx.MBeanServerBuilderImpl -Djava.awt.headless=true -Dresin.home=/usr/local/resin3.1.8-rtuku/ -Xmx256m -Xss1m -Xdebug -Dcom.sun.management.jmxremote -Djava.util.logging.manager=com.caucho.log.LogManagerImpl -Djavax.management.builder.initial=com.caucho.jmx.MBeanServerBuilderImpl -Djava.awt.headless=true -Dresin.
    0028f000     72K r-x--  /lib/libnsl-2.3.4.so
    002a1000      8K rwx--  /lib/libnsl-2.3.4.so
    002a3000      8K rwx--    [ anon ]
    0031c000     84K r-x--  /lib/ld-2.3.4.so
    00331000      4K r-x--  /lib/ld-2.3.4.so
    00332000      4K rwx--  /lib/ld-2.3.4.so
    0033a000   1172K r-x--  /lib/tls/libc-2.3.4.so
    0045f000      4K r-x--  /lib/tls/libc-2.3.4.so
    00460000     12K rwx--  /lib/tls/libc-2.3.4.so
    00463000      8K rwx--    [ anon ]
    00467000    132K r-x--  /lib/tls/libm-2.3.4.so
    ……
    b7f50000      4K rwx--    [ anon ]
    b7f51000      4K r-x--    [ anon ]
    b7f52000      4K r-x--    [ anon ]
    bfcf1000     12K -----    [ anon ]
    bfcf4000   1012K rwx--    [ stack ]
    total   652340K

从中可以看出来加载的所有so和线程堆栈用掉的内存。据称，当anon在512K-4M之间的超过上千个的时候，可能就是在多线程上有问题了。

还有一个用途，比较偏门的。
比如一个squid服务器，前人直接cd进目录，然后./squid启用的服务。那怎么去知道这个squid到底在那个目录里呢？（尤其是发现惯用的/usr/local下哗哗的摆着五个squid目录……）

现在只要pmap 一下，第一条就给出了全路径。哈哈~~
