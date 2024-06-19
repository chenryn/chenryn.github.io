---
layout: post
theme:
  name: twitter
title: rsyslog 中 if 条件判断的限制
category: logstash
tags:
  - linux
  - rsyslog
---

Rsyslog 从 v6 以后，实现了全新的 rainerscript 语法，数据处理灵活度大大提高。我最近一直在把 logstash 的解析配置迁移到 rsyslog 中完成。结果今天碰到一个非常好玩的地方。由此也说明了，一切 DSL，都不要想当然的觉得它会有跟编程语言完全一样的行为。

事情是这样的：一段 JSON 日志，在 rsyslog 中经过下面一段逻辑：

```perl
    set $!datetime = exec_template("get_now_time");
    if ( $!msg!date ) then {
        reset $!datetime = replace($!msg!date, " ", "T") & "+0800";
    }
    if ( $!msg!video_time_duration ) then {
        set $!msg!video_duration_num = 0;
        set $!msg!video_duration_timesum = 0;
        set $!msg!video_first_duration = cnum($!msg!video_time_duration[0]!duration);
        foreach ( $.item in $!msg!video_time_duration ) do {
            if ( $.item!type == "1" ) then {
                reset $!msg!video_duration_num = $!msg!video_duration_num + 1;
                reset $!msg!video_duration_timesum = $!msg!video_duration_timesum + cnum($.item!duration);
            }
        }
        if ( $!msg!video_duration_num == 0 ) then {
            unset $!msg!video_duration_num;
            unset $!msg!video_duration_timesum;
        }
    }
```

数据中，`date` 是一个 String ，而 `video_time_duration` 是一个 Array。但是实际运行起来，发现输出的数据里，根据 `date` 处理得到了 `datetime` 新字段，却完全没有 `video_first_duration`, `video_duration_num` 和 `video_duration_timesum` 等新字段的踪影。

看来 rsyslog 里的条件判断是不能针对 Array 做判断了，于是我又改成下面这样：

```perl
    if ( $!msg!video_time_duration[0]!duration ) then {
```

这样获取的就是一个实际的 String 内容了。但是实际运行起来，输出数据里，不但没有应该被处理出来的新字段，反而还多了一段：`, "video_time_duration[0]!duration" : { }, `！

这就有点像 Perl5 里的 exists 指令在判断多层哈希键的时候的行为了，不存在的键先自动创建出来……但是：rsyslog 现在在 if 条件判断里用数组下标获取数据的时候，居然把整段认为是一个 key 的内容，实在是无奈了……

最后，这里只能上最原始的办法了：

```perl
    if ( $msg contains "video_time_duration" ) then {
```

以上。
