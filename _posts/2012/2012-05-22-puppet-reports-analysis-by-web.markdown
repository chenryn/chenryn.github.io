---
layout: post
theme:
  name: twitter
title: 【puppet系列】网页展示puppet的客户端报告
date: 2012-05-22
category: devops
tags:
  - puppet
  - dancer
  - perl
---

上篇说到怎样使用ENC脚本控制puppet的客户端配置，这篇说如何监控和展示客户端运行状态报告。

目前还是使用puppet默认的store方式，也就是报告都存在/var/lib/puppet/reports/$host/$dates.yaml里。所以分析只要针对这个目录下的文件即可，主要使用File::Stat和File::Find两个模块搞定。注意这两个模块在Perl5.16里是默认内核模块了~~

```perl
#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use File::Stat qw/:stat/;
use YAML::Syck;
use AnyEvent::Filesys::Notify;
use EV;

my $interval = "60";
my $watch_dir = "/var/lib/puppet/reports";

my $periodic = EV::periodic 0, $interval, 0, sub {
    my $dirs = watchdir($interval);
    process( $_, 'No reports return.' ) for @{$dirs};
};

my $notifier = AnyEvent::Filesys::Notify->new(
    dirs     => [ $watch_dir, ],
    interval => 0.5,
    filter   => sub { shift =~ /\.yaml$/ },
    cb       => sub {
        my @events = @_;
        for ( @events ) {
            if ( $_->type =~ m/^(created|modified)$/ ) {
                my $file = $_->path;
                my $logs = LoadFile($file)->{'logs'};
                for ( @{$logs} ) {
                    if ( $_->{'level'} eq 'err' ) {
                        process( $file, $_->{'message'} );
                    };
                };
            };
        };
    },
);

EV::loop();

sub process {
    my ( $path, $message ) = @_;
    if ( $path =~ m/\/([^\/]+\.opi\.com)/ ) {
        print $1," has err: ",$message,"\n";
    };
};

sub watchdir {
    my $interval = shift;
    my $dirs = grep { time - stat($_)->[9] > $interval } glob("${watch_dir}/*");
    return $dirs;
};

```
上面这个脚本，通过libev的timer和io分别完成对diretory的mtime的遍历和对file的inotify的监听。process作为公共处理函数，可以随意改造成sms/email/msn等等方式。    
定时器没有用AnyEvent的封装，因为没看到AE有periodic，只有timer。而在io运行的时候，timer是中断的。如果不停有文件inotify发生，timer就没法进行了……periodic的方式与timer不同，是绝对定时而不是相对定时——虽然我个人的浅薄理解觉得应该也被io阻塞，但试验结果是OK的。

```perl
#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Dancer;
use Template;
use YAML::Syck;
use File::Find;
use File::Stat qw/:stat/;
use POSIX qw/strftime/;
use Data::Section::Simple qw/get_data_section/;

set port   => "8080";
set daemon => 1;
set logger => 'console';

my $tt = Template->new(
#                       DEBUG => 'all',
                      );

my $ds_check = get_data_section('check.tt');

get '/' => sub {
    my $html = '<form action="/ppcheck">';
    $html .= 'Write an interval minutes for reports timestamp check: ';
    $html .= '<input type="text" name="interval"/> <input type="submit" value="submit" />';
    $html .= '</form>';
    return $html;
};

get '/ppcheck' => sub {
    my $interval = params->{'interval'} * 60 || 300;
    my $watch_dir = "/var/lib/puppet/reports";
    return "Too large number" if $interval > 60 * 60 * 24;   # one day

    my $context = {};
    $context->{'dirs'} = watch_timeout( $interval, $watch_dir );
    $context->{'logs'} = watch_errlogs( $interval, $watch_dir );

    my $output;
    $tt->process(\$ds_check, $context, \$output);
#    $tt->process(\*DATA, $context, \$output);
#    seek *DATA, 1234, 0;
    return $output;
};

sub watch_timeout {
    my ( $interval, $watch_dir ) = @_;
    my @dirs = grep { time - stat($_)->[9] > $interval } glob("${watch_dir}/*");
    my @ret;
    for ( @dirs ) {
        my $dirtime = strftime("%F %T", localtime(stat($_)->[9]));
        my $dirname = $1 if $_ =~ s#([^/]+\.opi\.com)#$1#;
        push @ret, {name => $dirname, time => $dirtime, };
    };
    return \@ret;
};

sub watch_errlogs {
    my( $interval, $watch_dir ) = @_;
    my( $wanted, $list_reporter ) = find_file_by_mtime($interval);
    File::Find::find( $wanted, $watch_dir );
    my @ret = $list_reporter->();
    return \@ret;
};

sub find_file_by_mtime {
    my $interval = shift;
    my @found = ();
    my $finder = sub {
        if ( -f $File::Find::name && time - stat($File::Find::name)->[9] < $interval ) {
            my $yaml = YAML::Syck::LoadFile($File::Find::name);
            my @logs = grep { $_->{'level'} eq 'err' } @{$yaml->{'logs'}};
            for ( @logs ) {
            push @found, { host => $yaml->{'host'}, message => $_->{'message'}, };
            };
        };
    };
    my $reporter = sub { @found };
    return( $finder, $reporter );
};

dance;

__DATA__
@@ check.tt
<div id="timeoutdirs">
List of nodes whose report is timeout: <br />
<ul>
[% FOREACH dir IN dirs %]
<li style="width:200px;float:left">[% dir.name %]</li><li style="width:200px;margin:0;float:left">[% dir.time %]</li>
[% END %]
</ul>
</div>
<br /><hr /><br />
<div id="runerrlogs">
Error messages of running nodes: <br />
<ul>
[% FOREACH log IN logs %]
<li style="width:200px;float:left">[% log.host %]</li>
<li style="width:400px;margin:0;float:left">[% log.message %]</li>
[% END %]
</ul>
</div>
```
这个脚本实现的功能其实和上面那个类似。不过报警改成web页面，event触发改成web请求触发。    
这里两个新难点：

其一是没有inotify后如何根据web请求参数查找范围内新建的报表。File::Find模块只有一个函数find(\&wanted,@dirs)。其中&wanted是不能传参进去的。    
在CPAN上看到一个叫做File::Find::Closures的模块，提供了一系列可以给File::Find使用的&wanted函数，包括一个示例。于是稍微改造一下，就写成了find_file_by_mtime()函数。

其二是因为偷懒没有用dancer建立完整项目，使用了perl virtual file来提供template。所以不能直接使用Dancer的template 'ttname', {var=>\$var};定义了。    
Template::Toolkit提供的process()可以操作的template来源很多，可以是字符串／文件／句柄。所以process(\*DATA)也是生效的。但是问题出现了：这样启动后，第一次访问正常；第二次访问返回空！    
打开Template的DEBUG看到，第二次访问的时候，从*DATA里读不到数据了。也就是说，必须重新seek回去——而且试验证明seek的起始点是shebang行。。。。    
所以只能先从__DATA__里读出数据，然后以字符串形式传递给process()了。    

这里用到了Data::Section模块。从CloudForecast项目里学来的。CloudForecast中的web页面，使用的Text::Xslate模板技术读取__DATA__。其中包括有index／server／servers／service等页面。也就是说，在一个__DATA__里实现了多个virtual file。用的就是Data::Section::Simple模块。以@@为标签分割即可。
