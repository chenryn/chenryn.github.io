---
layout: post
title: nginx编译优化压力测试（转）
date: 2009-11-21
category: nginx
---

默认nginx使用的GCC编译参数是-O，需要更加优化可以使用以下两个参数：

    --with-cc-opt='-O3' --with-cpu-opt=*

具体是什么cpu可以grep name /proc/cpuinfo查看，如果是inter xeon，就写--with-cpu-opt=pentium，如果是AMD，就写--with-cpu-opt=opteron。这样编译针对特定CPU以及增加GCC的优化。

针对优化后的结果，我们进行测试，结果表明使用-O2以及以上的参数，可以微量增加性能1%左右，而O2和O3基本可以认为是相同的。
{% highlight bash %}
./http_load -parallel 100 -seconds 10 urls
10811 fetches, 100 max parallel, 5.23252e+06 bytes, in 10 seconds
1.默认参数 -O
1087.2 fetches/sec, 526204 bytes/sec
msecs/connect: 45.5374 mean, 63.984 max, 1.008 min
msecs/first-response: 45.7679 mean, 64.201 max, 2.216 min
1088.9 fetches/sec, 527027 bytes/sec
msecs/connect: 45.0159 mean, 65.291 max, 0.562 min
msecs/first-response: 46.1236 mean, 67.397 max, 9.169 min
1102.2 fetches/sec, 533465 bytes/sec
msecs/connect: 44.5593 mean, 67.649 max, 0.547 min
msecs/first-response: 45.499 mean, 67.849 max, 2.495 min
2.优化编译后 -O2
1081.1 fetches/sec, 523252 bytes/sec
msecs/connect: 45.7144 mean, 63.324 max, 0.823 min
msecs/first-response: 46.1008 mean, 61.814 max, 4.487 min
1110.2 fetches/sec, 537337 bytes/sec
msecs/connect: 43.4943 mean, 60.066 max, 0.715 min
msecs/first-response: 45.756 mean, 62.076 max, 3.536 min
1107 fetches/sec, 535788 bytes/sec
msecs/connect: 44.872 mean, 3036.51 max, 0.609 min
msecs/first-response: 44.8625 mean, 59.831 max, 3.178 min
3.优化编译后 -O3
1097.5 fetches/sec, 531189 bytes/sec
msecs/connect: 45.1355 mean, 3040.24 max, 0.583 min
msecs/first-response: 45.3036 mean, 68.371 max, 4.416 min
1111.6 fetches/sec, 538014 bytes/sec
msecs/connect: 44.2514 mean, 64.831 max, 0.662 min
msecs/first-response: 44.8366 mean, 69.904 max, 3.928 min
1099.4 fetches/sec, 532109 bytes/sec
msecs/connect: 44.7226 mean, 61.445 max, 0.596 min
msecs/first-response: 45.4883 mean, 287.113 max, 3.336 min
{% endhighlight %}

