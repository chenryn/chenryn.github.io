---
layout: post
title: Lucene 查询中的距离查询(proximity query)
category: elasticsearch
tags:
    - Lucene
---

我们在使用 ELK 的时候，使用 Lucene querystring 语法的机会，远超过使用 Elasticsearch 的 query DSL。毕竟在搜索框里写语法比自己拼 JSON 简单多了。

不过一般我们用的 querystring 语法总是最简单的几样：

```
text
key:value
key:"term"
k1:v1 AND NOT k2:v2
```

80% 的情况下，这几个用法也就足够了。但总有剩下的 20% 的情况，还是需要我们来了解一些更复杂的语法。

举一个还算通用的场景：**我们在 ELK 里索引了访问日志。这时候需要查一下以 `/api/login` 开头的 URL 们的情况。**

我们没法确定 URL 里是不是只有 `/api/login` 一种可能。没准可能还有 `/api/oauth/login` 呢？没准可能还有 `login/weibo/api` 呢？

一般来说，日志进 ELK 都是采用标准分词器的。而很巧，`/` 就是标准分词器的停止词之一。所以，我们在搜索框里写 `api/login` 等效于 `api login`。那么太多可能都可以命中了。

这个时候，Lucene 查询语法里的距离查询(proximity query)就可以帮忙了：

`url:"api login"`

看起来很简单，无非是给加了一对双引号？！

没错，加引号以后，意味着这个短语查询必须是有序的，即只能命中*先出现api，再出现login*的文本了。这下就把 `login/weibo/api` 排除掉了。

其次，Lucene 距离查询默认的距离为 0，即只能命中*出现api之后，下一个term必须为login*的文本了。这些就把 `/api/oauth/login` 也排除了。

当然，如果这时候你日志里除了 `api/login` 还有 `api,login` 之类的文本，也是会命中的。不过在 url 字段里出现这个的概率不大，可以无视了~

如果你要搜的就是 `/api/oauth/login`，但是你不记得中间这个是不是 oauth，也可能是其他的吧，怎么办？

`url:"api login"~1`

后面加波浪线和距离即可。
