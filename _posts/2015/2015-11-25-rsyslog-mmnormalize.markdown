---
layout: post
theme:
  name: twitter
title: Rsyslog 的 mmnormalize 模块用法
category: rsyslog
---

mmnormalize 是 Rsyslog 内置的一种数据解析的方案，甚至有自己的官网：<http://www.liblognorm.com>可以阅读相关用法细节。它既不像 Rsyslog 的 rainerscript 那样采用 ERE 类型的简单正则，也不像 Logstash的 Grok 那样采用 PCRE 类型的复杂正则(一度通过添加 regex parser 引入过 PCRE，后来又删了)，而是自己设计了一套方式，其最核心的匹配语法就是 `%char-to:` 这种“向后匹配直到＊为止”。下面是一段解析 nginx 访问日志的 mmnormalize 配置，相信大家第一眼看上去都会晕：

```
rule=:"%client_ip:char-to:"%" %tcp_peer_ip:ipv4% - [%req_time:char-to:]%] "%verb:word% %url:word% %protocol:char-to:"%" %status:interpret:int:number% %latency:interpret:float:word% %bytes_sent:interpret:int:number% "%referrer:char-to:"%" "%user_agent:char-to:"%" %upstream_addrs:tokenized:, :tokenized: \x3a :regex:[^ ,]+% %upstream_response_times:tokenized:, :tokenized: \x3a :interpret:float:regex:[^ ,]+% %pipe:word% \t %host:word% cache_%cache:word%
```

不过上个月 liblognorm 做了一次重大版本更新，新的 v2 语法，添加了一个 **user-defined types** 的设计，这就有点类似 Grok 的预定义正则的意思啦。

所以，本文来详细说说，从 v1.1.0 开始，新增的一些 liblognorm 的 type 给我们处理 Rsyslog 数据带来的便利。

_normalize 的匹配规则叫做 rulebase，所以可以看到有些 rsyslog 介绍中，mmnormallize 配置文件的后缀名是 `*.rb`，可不要以为是用 Ruby 解析啊。_

```
version=2
type=@TIMESTAMP:%date:date-iso% %time:time-24hr%Z
type=@TIMESTAMP:%datetime:date-rfc5424%
type=@TIME:%resptime:float%
type=@TIME:-
rule=:%timestamp:@TIMESTAMP% %clientip:ipv4% %resptime:@TIME% %urlpath:string% %reqbody:json% %referer:quoted-string%

```

这行 rule 在 v2 中还可以写的更美观一些：

```
rule=:%[ {"type":"@TIMESTAMP", "name":"timestamp"},
         {"type":"literal", "text:" "},
         {"type":"ipv4", "name":"clientip"},
         {"type":"literal", "text:" "},
         {"type":"@TIME", "name":"resptime"},
         {"type":"literal", "text:" "},
         {"type":"string", "name":"urlpath"},
         {"type":"literal", "text:" "},
         {"type":"quoted-string", "name":"referer"},
         {"type":"literal", "text:" "},
         {"type":"json", "name":"reqbody"}
       ]%
```

Rsyslog 的 mmjsonparse 模块只能解析 CEE 格式，如果 msg 本身是纯 JSON 的，反而不能解析，这时候就可以用上 mmnormalize 的 json parser 了。

和 json 一样也是 v1.1 以后才加入的，还有 `char-sep` 和 `rest`，`char-sep` 和 `char-to` 的区别是前者是0到多个，后者是1到多个；`rest` 则用来收集当前位置到本行结尾的全部数据。

也就是说：`%capturename:char-sep:\x20` 等于 `%capturename:char-sep: %` 等于 `%{"type":"char-sep","name":"capturename","extradata":" "}%` 等于 `%capturename:char-sep{"extradata":" "}`。相当于 Grok 里的 `[^ ]*?`。其他类似。

如果觉得上面那种预定义太麻烦，毕竟响应时间无非就是数值或者横杆而已，那么这行还可以这么写：

```json
         {"type":"alternative",
          "parser": [
            {"name":"resptime", "type":"float"},
            {"type":"literal", "text":"-"}
          ]
         }
```

还有类似 logstash-filter-kv 插件的功能，比如把

    a:2,b:4, c:6, d:8

这段数据做切割处理的配置：

```
%{"name":"obj", "type":"repeat",
  "parser":[
    {"type":"string", "name":"key"},
    {"type":"literal", "text":":"},
    {"type":"number", "name":"val"}
  ],
  "while": {
    "type":"alternative", "parser": [
      {"type":"literal", "text":", "},
      {"type":"literal", "text":","}
    ]
  } 
}%
```

会解析得到下面这样的 JSON 结果：

```json
{ "obj": [
    { "val": "2", "key": "a" },
    { "val": "4", "key": "b" },
    { "val": "6", "key": "c" },
    { "val": "8", "key": "d" }
  ]
}
```

看起来似乎不是很 kv 的样子，不过对于写入 Elasticsearch 来说，却刚刚好符合 nested object 的设计！

不过目前，还有些匹配模式在 v2 中不支持的，还得继续使用 v1 模式：

```
rule=:%filesize:interpert:float:number%
```

有时候，明明你这个数据中是整形，但是因为 ES 的 mapping 问题或者其他原因，需要强制转换成浮点型。Rsyslog 本身的 rainerscript 只提供了 `cnum()` 函数，没有 `cfloat()`，那么我们只能在 mmnormalize 里做 interpert 转换了。而这个操作目前在 v2 版本中还不支持。

目前 liblognorm 所支持的所有匹配格式说明，见<https://github.com/rsyslog/liblognorm/blob/master/doc/configuration.rst>
