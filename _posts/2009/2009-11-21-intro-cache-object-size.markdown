---
layout: post
theme:
  name: twitter
title: cache驻留时间（六、大文件）
date: 2009-11-21
category: CDN
tags:
  - cache
---

话说上回提到大文件下载，公司除了apache以外，有些也是用squid做的。这回说说这方面的设置。
下载业务，首先要注意到的，第一是多线程，第二是断点续传。

第一个参数：maximum_object_size——这个参数规定了squid能缓存的最大文件大小；
第二个参数：range_offset_limit——这个参数规定了squid能预先读取的文件大小；
第三个参数：quick_abort_(min|max|pct)——这几个参数规定了squid是否继续传输中断请求的文件；

第一个参数很熟悉，就不用说了。

第二个参数，squid的官方解释是：Sets a upper limit on how far into the the file a Range request may be to cause Squid to prefetch the whole file.

也就是说这个参数当客户端请求的header中带有range标签时（也就是多线程下载），如果文件大小在这个参数的规定范围内，squid会预读取这段文件作为缓存。
但是要注意了：如果你把range_offset_limit设的比maximum_object_size还大的话，squid按规则，会每次预读取完文件之后，再毫不犹豫的把它从cache里扔出去！！

这还不算完…如果网民这个线程开的比较猛，并发上20个线程来下载，对于squid，它却只认其中一个最快的一个线程，也就是说很有可能在第一次缓存的时候，真正下载的流量，是文件大小的20倍，于是很大可能又超过了maximum_object_size，squid又毫不犹豫抛弃掉……带宽不是用来这么玩的呀~~其结果我们也看得到，那就是cacti上上窜下跳的流量图。

第三个参数，当客户端中断请求后，squid会比对文件剩余部分的大小，如果小于min，就继续从源站下载；如果大于max，就放弃；如果达到了pct的比率，也继续——嗯，很像refresh_pattern的定义模式。

【基本上就是这些，另外，和maximum_object_size相关的还有一个maximum_object_size_in_memory，也就是能缓存在内存里的大小。这是另一个方向，要是够狠，完全可以把squid全跑在mem里（--enable-storeio）把cache_dir设成null……】

最后，如果修改了这些参数，对普通的小文件加速服务，会有一定的冲击，最好的办法，还是在后端的web架构上进行区分；其次，把squid进行区分，一部分专门跑下载，而其他的禁用掉range，向跑下载的邻居转发请求。不过sibling靠ICP获取一个列表的摘要，很可能假命中。这又需要对下载邻居进行详细限定，架构变得复杂无比。。。

