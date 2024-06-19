---
layout: post
theme:
  name: twitter
title: 用 avbot 机器人记录 QQ 群聊天记录
category: devops
---

这是一件蛮有趣的事情。我因为做 logstash 的 QQ 群管理员，碰到了一个幸福的烦恼：群里有不少高水平且乐于分享的朋友时常给人解答问题，而且一来一回的能牵扯出来不少让人眼前一亮的实践，但是 QQ 聊天记录不像邮件列表和 IRC 那样可以很方便的长期保存共享给后来人学习查找！这简直是国内参与开源技术最头疼的一件事情了，知识没法复用，偏偏越是需要这些知识的人，越是喜欢通过 QQ 来寻求帮助！前两天偶然想到，其实可以通过机器人潜水进来获取聊天记录，然后发布出来！询问了一下 [@比尔盖子V](http://weibo.com/biergaizi) 童鞋，他推荐给我 [avbot](http://wiki.avplayer.org/Avbot) 项目。#妈蛋这名字怎能不吐槽#

作者非常 nice 的提供好了 RPM 可以直接安装在服务器上。所以安装步骤真的就没啥可讲的了。

不过这个项目本意是做 QQ、IRC 和 XMPP 的互联互通，所以把心思用来了 `--map` 的实现，作为我们这里只想单单记录 QQ 群聊天记录来说，它不支持指定只获取某个群的记录，所以最好的办法就是新申请一个 QQ 号，只加这一个群……

运行起来以后，会在当前目录下生成一个 `avlog.db` 库，记录聊天记录，同时生成一个 QQ 群号命名的目录，里面按日期存放当天的聊天记录的 HTML 文件。直接用 nginx 发布出来就好啦！

照搬 avbot 官网 demo 页面做好了 logstash 群聊天记录的查看搜索页，见：<http://logstash.chenlinux.com/>

下一步可以做的事情是做自动应答。已经测试过可以通过 RPC 接口收发消息。不过昨天碰到的一个怪事情是，没能准确收到 QQ 群号，于是变成了 none，结果发送就一直失败。这个重启进程让他重新获得一次就可以了。

收消息示例：

    curl 'http://localhost:6176/message'
    {
        "protocol": "qq",
        "channel": "315428175",
        "room":
        {
            "code": "3614128622",
            "groupnumber": "315428175",
            "name": "Logstash"
        },
        "op": "0",
        "who":
        {
            "code": "225519360",
            "nick": "田间",
            "name": "田间",
            "qqnumber": "",
            "card": ""
        },
        "preamble": "qq(田间): ",
        "message":
        {
            "text": "我们这暂时没运维   "
        }
    }

发消息示例：

    curl -XPOST http://localhost:6176/message -d '{"protocol":"qq","channel":"315428175","message":{"text":"Hi, my name is logstashbot, this message came from curl command!"}}'
