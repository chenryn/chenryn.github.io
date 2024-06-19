---
layout: post
theme:
  name: twitter
title: 用gearman汇总多台服务器的回滚日志
date: 2011-06-03
category: monitor
tags:
  - gearman
  - perl
---

gearman其实不是重点，因为我就是抄了一遍perldoc的样例而已。关键在服务器上的log4j日志是回滚的，所以需要配合回滚（猜测log4j的DailyRollingFile回滚方式类似mv resin.log resin.log-ymd && reload，这样在回滚后，FH还在resin.log-ymd上，就读不到新日志了）重启FH。
另：tail命令有个参数-F/--follow=name，可以锁定文件名而不是文件描述符，不知道这个功能是怎么做到的？
一步一步来：

* jobserver

```bash
cpan -i Gearman::Server
gearmand -d -L 10.168.170.25 -p 7003
```

* worker

```bash
cpan -i Gearman::Worker
```

然后看日志的脚本，其实也就是样例：
```perl
#!/usr/bin/perl -w
use Gearman::Worker;

my $worker = Gearman::Worker->new;
$worker->job_servers('10.1.1.25:7003');
$worker->register_function( watchlog => \&watchlog );
$worker->work while 1;

sub watchlog {
    my $job = shift;
    print $job->arg,"\n";
}
```

* client（也就是多台resin服务器上）

```bash
cpan -i Gearman::Client
```

然后是脚本：
```perl
#!/usr/bin/perl -w
use Gearman::Client;
use POSIX qw(strftime);

my $client = Gearman::Client->new;
$client->job_servers('10.1.1.25:7003');

&read;
while (1) {
    open FH1,'<','/tmp/pid.txt';
    my $childpid = <FH1>;
    close FH1;
    my $date=strftime("%H:%M:%S",localtime);
    if ($date eq '00:00:00') {
        kill 9,$childpid;
        sleep 1;
        &read;   
    }
}

sub read {
my $pid = fork();
if ($pid == 0) {
#这个$$不能直接赋值出去，所以采用文件方式，以后研究一下pipe啊之类的办法。
    open FH,'>','/tmp/pid.txt';
    print FH $$;
    close FH;
    open (FD,'<','resin.log') or die $!;
    while (1) {
       my $log = <FD>;
       sleep 1 and next unless $log;
       chomp $log;
       $client->dispatch_background('watchlog',$log);
       }
    close FD;
    }
}
```
