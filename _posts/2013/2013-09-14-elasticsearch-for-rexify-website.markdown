---
layout: post
theme:
  name: twitter
title: 用 ElasticSearch 支持 Rexify 网站的搜索功能
tags:
  - perl
  - elasticsearch
  - rex
---

最近给 Rexify 官网做[中文化](http://rex.perl-china.com)工作，除了文字翻译之外，还要负责把服务正常跑起来。网站本身就是一个 `Mojolicious` 写的小东西，用 `morbo html/website.pl` 命令直接运行就可以监听在 3000 端口，然后通过 nginx 代理发布即可。

不过官网上还有一个高级功能需要另外支持，那就是搜索。

Rexify 官网的搜索功能是通过 ElasticSearch 提供的。这里需要注意一点，官方提供的 `create_index.pl` 中，并不是直接把文件内容本身存入 ES 索引的(之前介绍过的 `devopsweekly_index.pl` 脚本就是这样做的)，而是编码成 Base64 之后再以附件形式存储。

一开始我没注意到这点，结果搜索结果里一直只有标题和链接，没有高亮内容。后来发现是存的 base64 编码后又很疑惑 Rexify 官网是如何把 base64 再解码回来到网页上显示的。幸亏后来想到去 ElasticSearch 官网搜索一下 base64 关键词，然后发现了专门的[介绍页面](https://github.com/elasticsearch/elasticsearch-mapper-attachments)。原来是有一个[插件](https://github.com/elasticsearch/elasticsearch-mapper-attachments)实现的附件解析，调用了 Apache Tika 库，也就意味着支持 HTML/XML/Office/ODF/PDF/Epub/RTF/TXT/ZIP/MP3/JPG/FLV/Mbox/JAR 等等各种格式的文件。

所以，安装这个插件，然后重建索引，就可以正常提供搜索功能了：

    /usr/share/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-mapper-attachments/1.9.0
    rexify-website/create_index.pl localhost 9200 html/templates

脚本本身超级简单，欢迎大家自行阅读。
