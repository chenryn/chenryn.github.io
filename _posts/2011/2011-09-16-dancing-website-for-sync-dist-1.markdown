---
layout: post
title: 写个同步分发系统(一)
date: 2011-09-16
category: dancer
tags:
 - perl
---

写程序这个事情，其实规划最麻烦。比方我其实并没留意过一个完整的同步分发系统都有哪些功能。权做练手，想到哪些写哪些好了。
最基础的部分:一个提交文件列表的页面，自动分析文件列表然后从源下载文件，中心下载完成后通知边缘节点开始；
其次：文件完整性的校验，同步和分发的进度报表页面，失败报表的重试选择和报警；
再次：系统分用户，不同用户可选节点指定分发，只查看当前用户的报表。
以上。
今天先完成最基础的部分。还是用dancer -a websync创建应用。然后创建views/websync.tt如下：
{% highlight html %}
</head><body>
<form name='urllist' action='/websync' method='post'>
<table border='1' align='center'>
<tr><td><% message %><% FOREACH url IN errurls %><% url %><br><% END %></td></tr>
<tr><td><textarea name='urllist' cols='64' rows='10'></textarea></td></tr>
<tr><td align="center"><input type="submit" name="submit" value="submit">
<input type="reset" name="cancel" value="cancel">
</td></tr>
</table>
</form>
</body></html>{% endhighlight %}
一如既往的难看……考虑是不是学下用dreamweaver画个稍微好看点的页面出来做layout啊……
然后是lib/websync.pm，如下：
{% highlight perl %}package websync;
use Dancer ':syntax';
use Gearman::Client;

our $VERSION = '0.1';
#Don't change index because there are so many otherthings to do! 
get '/' => sub {
    template 'index';
};

any ['get', 'post'] => '/websync' => sub {
    my @errurls;
    my $message = 'Write urllist under here.<br>Attention: The url format must like "http://img.domain.com/path/to/example.flv"';
    if ( request->method() eq 'POST' ) {
        my $url_pattern = qr(^http://[^/]+?\.\w+/);
        my @urllists = split ' ', params->{urllist};
        foreach ( @urllists ) {
            push @errurls, $_ and next unless m/$url_pattern/;
            peer_query($_);
        };
        $message = 'Sync begin, waiting please.<br>And there are some error urls. Please check them:<br>';
    };
    template 'websync', { 'message' => $message, 
                          'errurls' => \@errurls, 
                        };
};

sub peer_query {
    my $url = shift;
    my @job_servers = qw(127.0.0.1:7003 192.168.0.2:7004);
    my $client = Gearman::Client->new;
    $client->job_servers(@job_servers);
    $client->dispatch_background('websync', $url);
};

true;{% endhighlight %}
嗯，这里试着用了gearman而不是fork，一个是考虑到可能web系统跟中心存储不在一起；另一个是考虑之后需要用mysql存储分发状态，可以把gearman::client改成mysql的trigger形式。
然后是worker.pl，运行在中心存储上，接受job，完成下载，然后通知其他节点继续：
{% highlight perl %}#!/usr/bin/perl -w
use Gearman::Worker;
use LWP::Simple;
use Net::SSH::Perl;
use POSIX ':WNOHANG';
$SIG{CHLD} = sub {waitpid(-1,WNOHANG)};

my @job_servers = qw(127.0.0.1:7003 192.168.0.2);
my $worker = Gearman::Worker->new;
$worker->job_servers(@job_servers);
$worker->register_function( websync => \&websync );
$worker->work while 1;

sub websync {
    my $job = shift;
    my @path = split('/', $job->arg);
    my $filepath = '/var/www/';
    foreach ( 2 .. $#path - 1 ) {
        $filepath .= $path[$_].'/';
        mkdir $filepath unless -d $filepath; 
    };
    sync_get($job->arg, $filepath . $path[-1]);
};

sub sync_get {
    my ( $url, $file ) = @_;
    my $http_code = getstore($url, $file);
    dist($file) if $http_code =~ m/^2/;
};
#I will rewrite this function to use gearman too~
sub dist {
    my $file = shift;
    my @remote = qw(1.1.1.1 2.2.2.2);
    foreach(@remote){
      unless(fork){
        my $ssh = Net::SSH::Perl->new($_);
        $ssh->login(root, passwd);
        $ssh->cmd("rsync 192.168.0.2:$file $file");
      };
    };
};{% endhighlight %}
不过想到，其实可以在remote上设定每15分钟一次rsync。这样节省掉中心的dist功能，改成remote上的rsync后，主动通过mysql汇报更新的list和md5。
明天开始改这种方式。
<hr>
晚饭回来，增加dancer在nginx上的部署方式。之前写过apache上用mod_perl的方式，这回因为正好电脑上有nginx，就改用nginx反代了：
首先安装一个perl的server，命令如下：
{% highlight bash %}# cpanm Plack Starman{% endhighlight %}
Starman是一个提供prefork方式运行的HTTP服务器。另外还有基于AnyEvent的Twiggy和基于Coro的Corona，不够因为我是在本机的colinux上做实验，装的是UBUNTU9.04系统，已经没有apt源装openssl了，所以Net::SSLeay模块无法安装，AnyEvent类型的也就不能用了。
启动命令如下：
{% highlight bash %}sudo -u www-data plackup -E production -s Starman --workers=2 -l /tmp/plack.sock -a /var/www/websync/bin/app.pl &{% endhighlight %}
该命令指定了运行用户，运行server核心，读取的配置文件，启动的worker进程，提供的socket接口。
然后就可以利用nginx的upstream功能，pass到这个socket接口上了。nginx.conf相关部分如下：
{% highlight nginx %}    upstream backendurl {
        server unix:/tmp/plack.sock;
    }

    server {
      listen       80;
      server_name  dancer.test.com;
      access_log logs/dancer_access.log;
      error_log  logs/dancer_err.log info;
      root /var/www/websync/public;
      location / {
        try_files $uri @proxy;
        access_log off;
        expires max;
      }

      location @proxy {
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass       http://backendurl;
      }
    }{% endhighlight %}
