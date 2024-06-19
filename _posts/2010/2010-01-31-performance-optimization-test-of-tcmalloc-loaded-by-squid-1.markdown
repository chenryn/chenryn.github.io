---
layout: post
theme:
  name: twitter
title: squid加载tcmalloc性能优化测试(原理)
date: 2010-01-31
category: squid
tags:
  - squid
  - tcmalloc
---

TCMalloc（Thread-Caching Malloc）是google开发的开源工具──“<a href="http://code.google.com/p/google-perftools/" title="google-perftools">google-perftools</a>”中的成员。其作者宣称tcmalloc相对于glibc2.3 malloc(aka-ptmalloc2)在内存的分配上效率和速度有6倍的性能提高，tcmalloc的常用场景是用于加速MySQL，不过据Wikipedia的hacker（Domas Mituzas）说，tcmalloc不仅仅对MySQL起作用，对squid也同样起作用（网上也有很多人在nginx上启用tcmalloc了），不过目前squid并没有official way来使用tcmalloc。
TCMalloc的实现原理和测试报告请见一篇文章：《<a href="http://shiningray.cn/tcmalloc-thread-caching-malloc.html">TCMalloc：线程缓存的Malloc</a>》
那么让我们赶紧给squid加载上tcmalloc，提高cache服务器在高并发情况下的性能，降低系统负载吧。
因为服务器是64位OS，所以要先安装libunwind库。libunwind库为基于64位CPU和操作系统的程序提供了基本的堆栈辗转开解功能，其中包括用于输出堆栈跟踪的API、用于以编程方式辗转开解堆栈的API以及支持C++异常处理机制的API。（又cp一句话，^=^）
```bashwget http://download.savannah.gnu.org/releases/libunwind/libunwind-0.99.tar.gz
tar zxvf libunwind-0.99.tar.gz
cd libunwind-0.99/
CFLAGS=-fPIC ./configure
make CFLAGS=-fPIC
make CFLAGS=-fPIC install```
普通的./configure&&make&&make install可不行哟~
然后开始安装tcmalloc:
```bashwget http://google-perftools.googlecode.com/files/google-perftools-1.8.1.tar.gz
tar zxvf google-perftools-1.8.1.tar.gz
cd google-perftools-1.8.1/
./configure --disable-cpu-profiler --disable-heap-profiler --disable-heap-checker --enable-minimal --disable-dependency-tracking
make && make install```
然后配置动态链接库，因为是之前是默认安装，这里自然就是/usr/local/lib了。
```bashecho "/usr/local/lib" > /etc/ld.so.conf.d/usr_local_lib.conf
/sbin/ldconfig```
然后给squid加载tcmalloc。官方推荐是重新编译：
先./configure，然后vi src/Makefile，修改如下：
```c
....
squid_LDADD =
-L../lib \
-ltcmalloc_minimal \
\
repl/libheap.a repl/liblru.a \
....
....
data_DATA =
mib.txt
LDADD
= -L../lib -lmiscutil -lpthread -lm -lbsd -lnsl -ltcmalloc_minimal
EXTRA_DIST =
....
```
保存，make&&make install，OK！
如果不愿意重新编译，那么动态加载吧。在/home/squid/sbin/squid -s之前执行export
LD_PRELOAD=/usr/local/lib/libtcmalloc_minimal.so就可以了。
最后运行lsof -n | grep tcmalloc看看，如果有
squid 3811   root mem REG 202,1 1364560 446102 /usr/local/lib/libtcmalloc.so.0.0.0
squid 3813  squid mem REG 202,1 1364560 446102 /usr/local/lib/libtcmalloc.so.0.0.0
这样的输出，加载成功。效果如何，跑上几天再说咯~
另：
据网上说，如果squid的configure参数中，有--with-large-files的话，是没法加载tcmalloc的。
