---
layout: post
title: 极光推送demo
category: monitor
tags:
  - android
---

之前已经陆续写过很多种告警的方式。今天再稍微试验一种更新潮一些的 —— 手机推送通知。原先我的想法是移植 HTML5 的 websocket + notification 页面到手机上。但是发现手机上的浏览器都还没有 notification 功能。即便是用 PhoneGap 包装 HTML5 应用，PhoneGap 的 notification API 也不是我想象中的状态栏通知，而是类似 js 的 alert 对话框。

不过这个时候我发现了极光推送。嗯，本来蛮有挑战的事情顿时变成了十分钟内解决的小菜：

整个过程如下：

### 注册帐号

官网地址: <http://jpush.cn>

### 新建应用

都是纯页面操作，填写应用名称而已。

### 下载 example 包

在应用详情里有下载链接。

### 用 adt eclipse 打开 example

adt eclipse 直接从 android 官网下载 adt-bundle-linux-x86-20130219.tar.gz 解压即可运行。更多配置见 android 官网说明。

然后在 File 菜单栏选择 new -> android application project 就可以新建自己的项目。然后创建自己的 workspace，把下好的 JPush example 包解压倒入workspace，然后就可以 run 了。

不过这里 run 会启动一个 android 虚拟机，很可能是连不上网的，原因似乎是 android vm 默认是 10.0.0.0 网段。

其实这时候我们会在 `workspace/push-example/bin/` 下发现一个 `push-example.apk` 文件。复制出来，通过豌豆荚或者别的什么工具直接装进自己手机就可以运行了。

### 测试页面发送通知

在极光的 portal 页面 <http://www.jpush.cn/apps/${your app key}/notification> 上可以直接提交通知内容。然后你就可以在手机状态栏通知上看到啦！

### 测试命令行发送通知

文档见<http://docs.jpush.cn/pages/viewpage.action?pageId=2621796>。

比如通过简易通知推送接口发送如下：

```bash
    #!/bin/sh
    #下面两个是你新建应用后就分配的
    APP_KEY=$1
    API_MasterSecret=$2
    #自赠序列号，这个最好是通过mysql的auto_increment管理
    sendno=2
    #这里有1,2,3,4,分别对应对指定IMEI/tag/alias/all的用户推送
    receiver_type=4
    verification_code=`echo -ne "$sendno$receiver_type$API_MasterSecret" | md5sum | awk '{print $1}'`
    #platform包括android,ios等等，可以用逗号分开写多个
    curl http://api.jpush.cn:8800/sendmsg/v2/notification -d "sendno=${sendno}&app_key=${APP_KEY}&receiver_type=${receiver_type}&platform=android&txt=123&verification_code=${verification_code}"
```

然后收到如下响应：

```bash
    {"sendno" :"2", "errcode":0,  "errmsg":"Succeed"}
```

手机也同时响起~成功。
