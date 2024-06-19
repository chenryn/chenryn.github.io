---
layout: post
theme:
  name: twitter
title: Gearman 任务的优先级
category: perl
tags:
  - gearman
---

今天同事跟我说 Gearman 客户端添加任务的时候似乎设置优先级没有效果，于是去实现了一下，发现 Gearman 的任务优先级只有在任务本身属性完全一致的时候才能起到作用。比如说：新提交的 background 任务优先级虽然是 high，也不会在已经提交的*非* background、优先级是 low 的任务之前执行。

考虑到之前没用过优先级，这里贴一下测试代码当做笔记：

worker
========

```perl
use Gearman::XS::Worker;
my $worker = new Gearman::XS::Worker;
my ($host, $port) = ('10.4.1.21', 4730); 
my $ret = $worker->add_server($host, $port);
my $ret = $worker->add_function("reverse", 0, \&reverse, $options);
 
while (1) {
  my $ret = $worker->work();
}
 
sub reverse {
  my $job = shift;
  my $workload = $job->workload();
  my $result   = $workload;
  printf("Job=%s Function_Name=%s Workload=%s Result=%s\n",
          $job->handle(), $job->function_name(), $job->workload(), $result);
 
  sleep(5);
  return $result;
}
```

client
========

```perl
use Gearman::XS::Client;
use Time::HiRes qw/time/;
my $client = new Gearman::XS::Client;
my ($host, $port) = ('10.4.1.21', 4730); 
my $ret = $client->add_server($host, $port);
while (1) {
    my ($ret, $job_handle) = $client->do_background("reverse", 'low'.time() );
} 
```

high-client
=============

```perl
use Gearman::XS::Client;
use Time::HiRes qw/time/;
my $client = new Gearman::XS::Client;
my ($host, $port) = ('10.4.1.21', 4730); 
my $ret = $client->add_server($host, $port);
while (1) {
    my ($ret, $job_handle) = $client->do_high_background("reverse", 'high'.time() );
} 
```


同时运行三个脚本，可以看到 worker 的输出，一直都是这样：

Job=H:YZSJHL1-21.opi.com:29434227 Function_Name=reverse Workload=high:1392887687.87583 Result=high:1392887687.87583
Job=H:YZSJHL1-21.opi.com:29434228 Function_Name=reverse Workload=high:1392887687.87594 Result=high:1392887687.87594
Job=H:YZSJHL1-21.opi.com:29434229 Function_Name=reverse Workload=high:1392887687.87605 Result=high:1392887687.87605

全都是高优先级的任务
