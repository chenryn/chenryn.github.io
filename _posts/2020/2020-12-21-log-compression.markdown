---
layout: post
title: 日志通用压缩算法的对比研究
category: logstash
tags:
  - elasticsearch
  - splunk
---

之前的文章介绍日志领域的研究方向时，曾经提到有些研究关注在日志的压缩方面，毕竟日志实在量太大了！日志易一个规模还可以的股份制银行客户，按照法律要求的存储时长计算磁盘大小，对应的硬件成本就是几千万。

但是这些研究大多有一个问题，那就是它们只考虑如何把日志的存储空间压缩到最小，却并不怎么考虑同时如何继续支撑已有的各种日志管理软件的读写方式——通常来说它们的做法都是自己设计一个索引或者模板提取方式，然后把日志转化过去。

那么，在通用的压缩算法基础上，日志领域还有什么可以研究和发挥的空间么？

前些天看到加拿大女王大学的一篇新论文，解答了这个问题。[A Study of the Performance of General Compressors on Log Files](https://users.encs.concordia.ca/~shang/pubs/Kundi_EMSE2020.pdf)

论文主要调研了三个问题：

* 通用压缩算法，对普通的文章和对日志数据有什么效果区别？
* 不同的日志文件大小，对压缩效果有什么影响？
* 不同的压缩级别，对压缩效果有什么影响？

## ELK 中的压缩实现

论文中主要取 ELK 和 Splunk 为最重要的背景参照。毫无疑问这是目前最主流的日志管理工具。文中介绍：“In addition, log management tools usually divide the input log data into small blocks (or slices) and then apply compression on each of the blocks, such that the compressed data could be decompressed and searched quickly (only the blocks containing the searched keywords need to be decompressed). For example, Splunk divides the input data into 128KB blocks and compresses each of them separately [15]. ELK by default splits log data into 16KB blocks. When a higher compression ratio is preferred, ELK splits log data into 60KB blocks.”

我想除了真的去看过[这部分源码](https://github.com/apache/lucene-solr/blob/master/lucene/backward-codecs/src/java/org/apache/lucene/backward_codecs/lucene50/Lucene50StoredFieldsFormat.java#L148)的人，大多数 ELK 用户可能并不知道 ES mapping 里的 "best_compression":true 配置其实是在修改这个 chunk_size 吧（确切的说其实是 60KB 和 512个 document 哪个先到）？

不过：对比一下 lucene 不同版本可以发现，lucene50 里还是60KB / 512doc，[lucene87 里](https://github.com/apache/lucene-solr/blob/master/lucene/core/src/java/org/apache/lucene/codecs/lucene87/Lucene87StoredFieldsFormat.java)已经改成了这样：

![](https://pic3.zhimg.com/v2-3e95f64f63bf2052f2abd62c26cff9fe_r.jpg)

快速压缩改成了 10*60KB / 1024doc，而最大压缩改成了10*48KB / 4096doc。对应的两次修改见：[LUCENE-9447: Make BEST_COMPRESSION better with highly compressible da… · apache/lucene-solr@913976d](https://github.com/apache/lucene-solr/commit/913976dbf78b3a6d937b3345e6231fee77e81fd4) 和 [Further tune Lucene87StoredFieldsFormat for small documents. (#1888) · apache/lucene-solr@e0a6490](https://github.com/apache/lucene-solr/commit/e0a64908d83750f296d4a1123b5edd7836101ca9)

也就是把一个 chunk 再切分成 10 个 subblock，然后还加上了 preset dictionary。这块我稍微百度了一下，好像可能再提高不到百分之十的压缩。

## 论文结论

言归正传，论文的测试数据是用的港中文开源的 loghub，这个算是目前最常用的了。参与测试的通用压缩算法包括三类，基于字典的，基于排序的，基于预测的。我们通常说的 gzip、lz4、lzma 就是基于字典的，bzip2 就是基于排序的，7z 的 ppmd 就是基于预测的。当然这里测试一共找了12 种实现。

所以，第一个问题的最终的结论：

1. 对自然语言文本压缩率最好的算法，对日志表现并不是最好的；
2. 对一种日志压缩效果最好的算法，对另一种日志也不一定最好；
3. 基于字典的算法，压缩和解压缩速度都不错，但是压缩比一般；
4. 压缩比最高的 PPMD 和 CM，对不同日志表现都挺稳定的，可能是日志在较大窗口内能出现的东西太容易预测了……
5. PPMD 的压缩速度虽然不行，但是好歹比 gzip 压缩自然语言文本的速度快点。（二者在自然语言文本上速度是3.97和13.8MB/s，而在日志上是15.64和33.33MB/s）

所以最后的建议是：

1. 纯粹做集中存储，选 PPMD 未尝不可，压缩比高，速度也只是慢一倍罢了。
2. 实时监控，资源有限，可以用 LZSS 替代 LZ77。
3. 实时分析，需要更好的解压速度，可以用 LZMA 替代 LZ77。
4. 压缩和解压都有速度要求，那么 LZ4 最稳定了。

然后是第二个问题，大小。这里又分成两个，第一个是总的文件大小，第二个是 chunk 的大小。总大小是给 log4j/logback 用的，应该多大做一次自动切分轮转合适。结论是：日志在比较小的时候信息熵合适压缩。这个小的意思大概是：16KB-8MB。而 chunk 的大小也就是最前面说的 ELK 和 splunk 的那个参数了。结论是：一般设为 128KB 比较平衡，如果看中压缩比和解压速度，可以扩大到 256KB，说明 ELK 和 splunk 这个参数都不是最优的——当然，如果按照 lucene87 的改动来看，又有点激进过头了

最后是第三个问题，级别。这个直接上结论吧。结论是：对自然语言，级别越高肯定压缩效果越好，但是对日志不一定。但是肯定都比默认级别好一些。对日志上高级别压缩消耗的资源比自然语言的还更多。

最后的最后，文章没有对比这些年在工业界比较有名的 snappy 啊，zstd 啊这些实现。不过作者本身把自己的对比测试库开源在 github 了，有兴趣也可以搞搞新的对比：[SAILResearch/suppmaterial-20-kundi-log_compression](https://github.com/SAILResearch/suppmaterial-20-kundi-log_compression)
