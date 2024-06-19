---
layout: post
theme:
  name: twitter
date: 2012-10-17
title: 用Juggernaut实时推送syslog分析结果
category: web
tags:
  - syslog
  - javascript
  - websocket
  - redis
  - perl
---
大家一般都会用rsyslog或者syslog-ng之类的收集系统日志。不过收集之后的处理就各种各样了。这里提供一个简单的处理，按日期保存成文件，然后定时分析新增内容，通过websocket推送到页面报警。这对于像磁盘错误等信息比较有用。因为等nagios之类的监控反应出来，故障可能就已经到你措手不及的地步了。

这里介绍一下Juggernaut项目，作者当初还在上学的时候就开始搞这个项目并最终因为这个项目找到的工作。不过几个月前他宣布不再维护了，因为他觉得html5已经普及，大家直接写websocket就够了。额，在口年的中国，我觉得Juggernaut还是很有意义的。项目地址：<https://github.com/maccman/juggernaut>。

举例中有ruby、js和python的样例，不过既然是用Redis传消息，那么改成perl的代码跟python的比差距也就很小了。

```perl
#!/usr/bin/perl
use AnyEvent;
use Getopt::Long;
use Redis;
use JSON;
use POSIX qw/ strftime /;
use warnings;
use strict;
use 5.010;
# 后台运行
use App::Daemon qw( daemonize );
$App::Daemon::as_user    = "root";
daemonize();
# 设定调试和间隔
my ($debug, $interval, $help);                                                                                                                                                        
GetOptions(                                                                                                                                                                           
    "debug|d" => \$debug,                                                                                                                                                             
    "interval|i=i" => \$interval,                                                                                                                                                     
    "help|h" => \$help,                                                                                                                                                               
);                                                                                                                                                                                    
if( $help ) {
    say "Usage: $0 [start|stop|-X] -d -i num";
    say "       -X means run frontend;";
    say "       -d means debug for timer and submit;";
    say "       -i means define a special interval seconds for regexp and submit, default set 300s.";
};
$interval = 300 unless $interval;

my @str = ();
# syslog的pri，定义见http://www.ietf.org/rfc/rfc3164.txt。因为本例只收集kernel信息，即Facility = 0,所以PRI = 0 * 8 + Severity。这里为了页面好看直接写成bootstrap里button的class了。
my @pri = qw(
    btn-inverse
    btn-danger
    btn-warning
    btn-success
    btn-info
    btn-primary
    btn
    disabled
);
# syslog格式<IP> <TIME> <PRI> kernel: <MSG>
# 注意最后msg里的\S.+，因为当内存出错等情况时，msg里开头会以空格表示附属关系
my $re = qr/((?:\d{1,3}\.){3}\d{1,3}) \[(\w+ \d+ \d{2}:\d{2}:\d{2})\] <(\d+)> kernel: (\S.+)/;
# 目前是直接收集成时间格式命名了，所以每天crond里要restart脚本，如果是日志名不变，crond切割的，那么脚本可以一直跑
open(my $r, "-|", "tail", "-F", '/data1/syslog/kern.' . strftime("%Y%m%d", localtime) . '.log' ) or die "can't fork: $!";

my $io = AnyEvent->io(
    fh => $r,
    poll => "r",
    cb => sub {
        my $input = scalar <$r>;
        return if $input =~ /repeat|suppress|window/;
        push @str, $input;
    }
);

my $w = AnyEvent->timer(
    after => $interval,
    interval => $interval,
    cb => sub {
        my $data;
        say "######## ",time if $debug;
        for ( @str ) {
            next unless $_ =~ $re;
            my ( $ip, $time, $level, $msg ) = ( $1, $2, $3, $4 );
            next if exists $data->{$ip};
            $data->{$ip} = classify($msg);
            submit( $time, $ip, $pri[$level], $data->{$ip}, $msg );
        };
        @str = ();
    },
);
AnyEvent->condvar->recv;

sub submit {
    my @msg = @_;
    say @msg if $debug;
    my $redis = Redis->new( server => '198.168.0.2:6379' );
    $redis->publish("juggernaut", to_json({
        channels => ['channel1'],
        data => \@msg,
    }));
};

sub classify {
    my $msg = shift;
    if ( $msg =~ /TCP|UDP|SYN|socket/ ) {
        'network';
    } elsif ( $msg =~ /segfault|swap|mem|allocation/ ) {
        'memory';
    } elsif ( $msg =~ /IPMI|EXT|cciss|scsi|mpt|usb|DRAC|sd\w/ ) {
        'disk';
    } elsif ( $msg =~ /CPU|IRQ/ ) {
        'cpu';
    } else {
        'unknown';
    };
};
```

然后写html页面来接收。

```html
<html>
<head>
  <meta name="charset" content="utf-8">
  <title>syslog-push-webUI</title>
  <script src="http://192.168.0.2:8080/application.js" type="text/javascript" charset="utf-8"></script>
  <script src="/javascripts/jquery-1.7.2.min.js " type="text/javascript" charset="utf-8"></script>
</head>
<body>
  
  <div id='syslog' style="overflow-y: scroll; border: #999">
    <ul class="unstyled" id='msg'>
    </ul>
  </div>
  <div><button class="btn" id="notify-permission-button">开启桌面通知</button></div>

  <script type="text/javascript" charset="utf-8">
    
    $(function() {

      var log = function(data){
        var msg;
        $('#msg li:gt(40)').remove();
        if( typeof(data) == 'string' ) {
          msg = data;
        } else {
          msg = '<blockquote>';
          msg += '<button type = "button" class="btn-mini ' + data[2] + '">' + data[3] + '</button>: ';
          msg += '<code>' + data[4] + '</code>';
          msg += '<small><strong>' + data[1] + '</strong> ';
          msg += '<cite>' + data[0] + '</cite></small>';
          msg += '</blockquote>';
        }
        $('#msg:first-child').prepend('<li>' + msg + '</li>');
      };

      var jug = new Juggernaut({
        secure: ('https:' == document.location.protocol),
        host: document.location.hostname,
        port: 8080 || document.location.port
      });
      
      jug.on("connect", function(){ log("<code>Connected</code>") });
      jug.on("disconnect", function(){ log("<code>Disconnected</code>") });
      jug.on("reconnect", function(){ log("<code>Reconnecting</code>") });
      
      jug.subscribe("channel1", function(data){
        log(data);
        if ( data[2] != 'btn' ) {
          desk_notify(data);
        };
      });

      var desk_notify = function(data) {
        if(window.webkitNotifications){
          if (window.webkitNotifications.checkPermission() > 0) {
            RequestPermission(desk_notify(data));
          } else {
            var notification = webkitNotifications.createNotification(
              'http://a.xnimg.cn/imgpro/app/mobile/renren_phone_icon2.png',
              data[1],
              data[4]
            );
            notification.show();
          }
        }
      }

      function RequestPermission(callback) {
        window.webkitNotifications.requestPermission(callback);
      }

      $('#notify-permission-button').click(function(){
        $('#notify-permission-button').hide();
        desk_notify(['','syslog realtime push','','','开启']);
      });
    });

  </script>
</body>
</html>
```

这里除了juggernaut的代码以外，还加上了chrome独有的webkitnotification功能，这样使用chrome的话，可以打开桌面通知，监控效果更佳～

注意：chrome桌面通知的权限授予，不能通过页面代码自动触发，必须显式的用button.click来触发。

__2013 年 2 月 17 日更新：__

我的 Ubuntu 12.10 更新到 firefox 18.0.2 版本后，以上代码也可以出现桌面通知了。不过奇怪的是：第一至今没有看到哪里有这个更新说明；第二我确实没有安装相关的extension，事实上我一共就安装了 firebug/xmarks/adblocks 三个扩展。
