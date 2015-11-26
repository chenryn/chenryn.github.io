---
layout: post
title: mysql测试小工具mybench试用
date: 2011-06-14
category: testing
tags:
  - perl
  - MySQL
---

小型的mysql测试工具，主要有自带的mysqlslap、super-smack和mybench。嗯，我这里的小型的意思是指工具安装过程简单。
mysqlslap的使用方法遍地都是，就不先详细写了。根据个人偏好写写mybench吧，毕竟是perl的。
安装很简单，如下：
```bashcpanm DBI DBD::mysql Time::HiRes
wget http://jeremy.zawodny.com/mysql/mybench/mybench-1.0.tar.gz
tar zxvf mybench-1.0.tar.gz
cd mybench-1.0
perl MakeFile.PL && make && make install```
但是使用就不是太简单了——mysqlslap会自己生成（-a选项）sql，super-smack则带了一个gen-data程序生成数据然后自动导入，但是mybench没有，所以只能自己搞定数据。
不过mybench还是自己生成了一个测试模版的脚本在/usr/bin/bench_example，很简单的就知道怎么做了。
example如下：
```perl#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use MyBench;
use Getopt::Std;
use Time::HiRes qw(gettimeofday tv_interval);
use DBI;

my %opt;
Getopt::Std::getopt('n:r:h:', \%opt);
#这是我见过的最hardcode的perl脚本了（呃，除了我自己写的垃圾），连db库、用户名、密码都不给运行参数的
my $num_kids  = $opt{n} || 10;
my $num_runs  = $opt{r} || 100;
my $db        = "test";
my $user      = "test";
my $pass      = "";
my $port      = 3306;
my $host      = $opt{h} || "192.168.0.1";
my $dsn       = "DBI:mysql:$db:$host;port=$port";

my $callback = sub
{
    my $id  = shift;
    my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1 });
#为测试准备的请求，测select就写select，测insert就写insert呗~
#如果不修改，也就是说测试用的是test.mytable表，而且必须有一个列叫id
    my $sth = $dbh->prepare("SELECT * FROM mytable WHERE ID = ?");

    my $cnt = 0;
    my @times = ();

    ## wait for the parent to HUP me
    local $SIG{HUP} = sub { };
    sleep 600;
#脚本定义的每个进程执行多少次请求
    while ($cnt < $num_runs)
    {
        my $v = int(rand(100_000));
        ## time the query
        my $t0 = [gettimeofday];
#真正的执行sql请求，通过上面的rand知道，之前准备的test.mytable的id列必须是int格式，同时不少于10w行（又一处hard）
        $sth->execute($v);
#通过前后两次gettimeofday获得sql的exec耗时
        my $t1 = tv_interval($t0, [gettimeofday]);
#完成一次请求执行，加入数组
        push @times, $t1;
        $sth->finish();
        $cnt++;
    }

    ## cleanup
    $dbh->disconnect();
#计算本进程全部请求的各项数据，几个大小和均来自MyBench模块
    my @r = ($id, scalar(@times), min(@times), max(@times), avg(@times), tot(@times));
    return @r;
};
#将上面这个函数交给MyBench模块的fork_and_work执行，即并发指定数量请求，返回总的结果
my @results = MyBench::fork_and_work($num_kids, $callback);
#计算总的数据
MyBench::compute_results('test', @results);

exit;

__END__```
然后看看/usr/lib/perl5/site_perl/5.8.8/MyBench.pm，主要内容就是fork和compute：
```perlpackage MyBench;
use strict;

$main::VERSION = '1.0';

use Exporter;
@MyBench::ISA = 'Exporter';
#导出求最大值、最小值、平均值、综合值的函数给外面用
@MyBench::EXPORT = qw(max min avg tot);

sub fork_and_work($$)
{
#关闭输出缓冲
    $|=1;

    use strict;
    use IO::Pipe;
    use IO::Select;

    $SIG{CHLD} = 'IGNORE';      ## let the kids die

    my $kids_to_fork = shift;
    my $callback     = shift;
    my $num_kids     = 0;
    my @pipes        = ();
    my @pids         = ();
    my $pid          = undef;

    print "forking: ";

    while ($num_kids < $kids_to_fork)
    {
#用IO::Pipe管道方式来传递父子进程的信息
        my $pipe = new IO::Pipe;
#fork进程开始
        if ($pid = fork())
        {
            ## parent
            $num_kids++;
#每fork完成一个打印一个+号
            print "+";
#从管道中读取数据
            $pipe->reader();
            push @pipes, $pipe;
            push @pids,  $pid;
        }
        elsif (defined $pid)
        {
            ## child
#打开管道写入数据的功能
            $pipe->writer();
#执行select_example脚本传入的mysql请求测试函数
            my @result = $callback->($num_kids);
#把结果写入管道
            print $pipe "@result\n";
#关闭管道
            $pipe->close();
            exit 0;
        }
        else
        {
            print "fork failed: $!\n";
        }
    }

    print "\n";

    ## give them a bit of time to setup
    my $time = int($num_kids / 10) + 1;
    print "sleeping for $time seconds while kids get ready\n";
    sleep $time;

 #发送SIGHUP信号给callback函数
    kill 1, @pids;

    ## collect the results
    my @results;

    print "waiting: ";
#从管道中读取数据到数组
    for my $pipe (@pipes)
    {
        my $data = <$pipe>;
        push @results, $data;
        $pipe->close();
        print "-";
    }

    print "\n";

    return @results;
}

sub compute_results(@)
{
    my $name = shift;
    my $recs = 0;
    my ($Cnt, $Min, $Max, $Avg, $Tot, @Min, @Max);

    while (@_)
    {
        ## 6 elements per record
        my $rec = shift; chomp $rec;
        my ($id, $cnt, $min, $max, $avg, $tot) = split /\s+/, $rec;

        $Cnt += $cnt;
        $Avg += $avg;
        $Tot += $tot;

        push @Min, $min;
        push @Max, $max;

        $recs++;
    }

    $Avg = $Avg / $recs;
    $Min = min(@Min);
    $Max = max(@Max);

    my $Qps = $Cnt / ($Tot / $recs);

    print "$name: $Cnt $Min $Max $Avg $Tot $Qps\n";
    print "  clients : $recs\n";
    print "  queries : $Cnt\n";
    print "  fastest : $Min\n";
    print "  slowest : $Max\n";
    print "  average : $Avg\n";
    print "  serial  : $Tot\n";
    print "  q/sec   : $Qps\n";
}

## some numerical helper functions for arrays

sub max
{
    my $val = $_[0];
    for (@_)
    {
        if ($_ > $val) { $val = $_; }
    }
    return $val;
}

sub min
{
    my $val = $_[0];
    for (@_)
    {
        if ($_ < $val) { $val = $_; }
    }
    return $val;
}

sub avg
{
    my $tot;
    for (@_) { $tot += $_; }
    return $tot / @_;
}

sub tot
{
    my $tot;
    for (@_) { $tot += $_; }
    return $tot;
}

1;```
好了，开始准备数据，比较懒，直接用super-smack的gen-data先出了一些./gen-data  -n 100000 -f %n,%80-12s%12n,%512-512s,%d > /root/data，然后进mysql里执行：
```mysql
USE test;
CREATE TABLE mytable (id INT(11) NOT NULL AUTO_INCREMENT, col1 CHAR(100), col2 CHAR(100), col3 INT(11), PRIMARY KEY (id) )ENGINE=InnoDB DEFAULT CHARSET=utf8;
LOAD DATA LOCAL INFILE 'data' REPLACE INTO TABLE 'mytable' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';
INSERT INTO mytable (col1,col2,col3) SELECT col1,col2,col3 FROM mytable;```
最后执行./select_bench -h 10.168.170.92 -n 10 -r 1000就能看到结果了：
forking: ++++++++++
sleeping for 2 seconds while kids get ready
waiting: ----------
test: 10000 0.00017 0.006809 0.0010413514 10.413514 9602.9063772325
  clients : 10
  queries : 10000
  fastest : 0.00017
  slowest : 0.006809
  average : 0.0010413514
  serial  : 10.413514
  q/sec   : 9602.9063772325
