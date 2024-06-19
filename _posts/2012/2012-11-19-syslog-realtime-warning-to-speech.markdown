---
layout: post
theme:
  name: twitter
title: syslog实时报警"说出来"
category: monitor
tags:
  - websocket
  - perl
  - syslog
---
syslog应该是大家最常用的，也基本可以说是最重要的服务器监控信息来源了。

syslog的传输，应该不用再说，哪怕在百度里搜都有足够多的靠谱结果。而关于报警的问题，之前我也写了好几篇，比如[《用Juggernaut实时推送syslog分析结果》](/2012/10/17/juggernaut-for-syslog-check)讲了如何用websocket推送结果，[《Chrome的APP简单用法》](/2012/11/09/chrome-app-demo)讲了如何利用chrome后台页面开机自动运行进行桌面提示。

那么，如果我既不想开网页看，也不好安装chrome浏览器，有没有够简便的办法接收呢？有！Linux社区从来不缺乏各种神奇工具。下面介绍两个同样强大的提示办法。

第一个，非chrome型的桌面通知notify-send命令，依发行版不同，可能属于libnotify-tools或者libnotify-bin包，自己搜索即可；

第二个，Espeak命令，著名Text To Speech软件，虽然电子音怪了点，但是支持中文而且文件很小，同样直接在源里安装即可。

下面就是如何把这两个强大的工具和server结合起来的问题了，出动胶水语言代表perl。代码如下：

```perl
use Mojo::UserAgent;
use JSON;

my $ua = Mojo::UserAgent->new();
my ( $sid, $ws );
# 本来用Protocol::WebSocket::Handshake::Client模块，指定IP和端口，自动会获取sid拼ws地址的，不过测试发现open后没反应。奇怪
LABEL:
$sid = (+split(/:/, $ua->get('http://syslog.domain.com:8080/socket.io/1/')->res->body))[0];
$ws = "ws://syslog.domain.com:8080/socket.io/1/websocket/${sid}";
$ua->websocket( $ws => sub {
    my ($ua, $tx) = @_;
    $tx->send('3:::{"type":"subscribe","channel":"syslog"}');
    $tx->on(finish  => sub {
        # 很怪的是，mojo::useragent的websocket client总是在不到一分钟内就进入on_finish状态，所以这里只好返回重连
        Mojo::IOLoop->stop;
        goto LABEL;
    });
    $tx->on(message => sub {
        my ($tx, $msg) = @_;
        if ( length( $msg ) > 5 ) {
            my $syslog = from_json( substr( $msg, 3 ) );
            notify( $syslog );
        };
    });
});
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

sub notify {
    my $data = $_;
    return if $data->[2] eq 'btn';
    exec("notify-send \"$data->[0] $data->[1]\" \"$data->[3] $data->[4]\"");
    # 注意设定-s 120，默认是175，念得飞快
    exec("espeak -vzh+f2 -s 120 \"$data->[1]\""); # 指定中文报ip，不然很难听懂
    # f是女生，m是男声，至于第几个声音，我没听出来多大差别，都跟九十年代初电影里的机器人一样
    exec("espeak -ven+m2 -s 120 \"$data->[3] $data->[4]\""); # 指定英文报内容，不然用中文的声音念更难听懂
};
```

以上抛砖引玉，大家可以试试Ekho(余音)，这是国人开发的真人语音TTS开源软件，还支持粤语，文言文等选择，汗……
