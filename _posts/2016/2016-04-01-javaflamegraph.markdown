---
layout: post
theme:
  name: twitter
title: 用火焰图看 elasticsearch 的资源占用
category: monitor
tags:
    - nodejs
    - elasticsearch
    - flamegraph
---

我们都很习惯在压测 nginx 等服务的时候，利用 systemtap 完成 flamegraph 火焰图来看具体哪个函数占用 CPU 资源过多了。那么，对 Java 实现的 elasticsearch，有没有类似办法呢？

JDK 自带有 jstack 命令，可以获取相关信息，其实只要一个可视化的过程就行了。而社区也有人早已做好。下面就是 nodejs 的 javaflamegraph 库的安装使用过程：

```
wget https://nodejs.org/download/release/v5.10.0/node-v5.10.0-linux-x64.tar.gz --no-check-certificate
tar zxvf node-v5.10.0-linux-x64.tar.gz
cd node-v5.10.0-linux-x64
./bin/npm install javaflamegraph
../../bin/npm run start `ps aux|grep elasticsearc[h]|awk '{print $2}'`
```

确保 jstack 命令可用(flame-gen.sh 里是直接调用的，注意 PATH)，确保当前目录可写。

等待几十秒后，中止进程。用浏览器打开当前目录下的 flame.html。可以看到如下效果：

![](/images/uploads/esflame0.png)

鼠标大概在上面移动一下，可以看到大概 segment merge 和 bulk thread 各占了 ES 进程资源消耗的半壁江山。

我们再点击一个 bulk thread，看看细节：

![](/images/uploads/esflame1.png)

可以看到其中 primary 和 replica 各占一部分。两者各自包括各自的三块：lucene 的 indexWriter、loadCurrentVersionFromIndex、translog。

在集群压测中，这三块的占比大概是后面两个加起来不到15%的样子，如果做日志场景，其实有可能用不上 version 检查，可以省掉大概 10% 的资源消耗。不过，谁都难免有异常要 retry，通过 version 检查避免重复的 indexing，也是有利的。所以总体来说：elasticsearch 在索引性能方面，做的应该是挺好了。要提高这个速度，可能更需要关心的是 lucene 层面的方案，比如分词方式、结构化程度等等~
