---
layout: post
title: IPC::Locker模块介绍
category: perl
---
当你需要给一个集群的某项服务做简单的排他性管理的时候，强力推荐Veripool公司的一系列模块：IPC::Locker、Schedule::Load。

今天先说IPC::Locker模块。部署很简单，直接在集群所有节点上运行cpanm IPC::Locker即可。该模块依赖几个都是perl的核心模块比如IO::Socket::INET、IO::Poll和POSIX。所以理论上你也可以把代码打个包分发。

随包分发的还有几个现成的脚本程序lockerd、lockersh、pidstat、pidstatd和pidwatch。

后面三个关注的remote设备上的pid是否存在等，但是相信一般情况下，我们不会自己来通过pid管理集群，所以在使用上只要理解lockerd和lockersh其实也是用pidstatd来解决pid问题的就够了。

其实代码很简单，看看就明白，无非就是lockerd用的IPC::Locker::Server是启动了一个IO::Socket::INET做tcp server，主要维护几个东西，一个是@{$self->{lock}}列表，一个是@{$self->{host}}列表，一个是$self->{locked}的Bool值。

而lockersh用的IPC::Locker则是连接上lockerd的端口，检查$self->{locked}状态，如果没locked就发送LOCK请求，然后fork一个进行exec你定义的shell命令，执行完成后，unlock发送UNLOCK请求给lockerd。

做个简单实验：

1. 在serverA上运行lockerd &     
2. 在serverB上运行lockersh --dhost serverA --lock test_task 'while true;do echo "OK";done'
3. 在serverC上运行lockersh --dhost serverA --lock test_task 'while true;do echo "OK";done'
4. 在serverD上运行lockersh --dhost serverA --lock other_task 'while true;do echo "OK";done'

观察一下，结果是在serverB和serverD上同时在执行echo "OK"。而serverC被lock住了。继续：

5. 在serverB的session上按下Ctrl+C终止程序，然后再次运行上述命令
6. 在serverC的session上按下Ctrl+C终止程序

观察一下，结果是停止B时C的即开始，停止C的后B的继续。这些都不影响serverD的运行。

7. 终止serverD的程序，改为运行lockersh --dhost serverA --lock test_task 'while true;do echo "OK";done'

观察一下，发现B、C、D是按照lockersh的执行次序解锁的。因为hostlist是一个列表，在server上是用for循环的。

注意：必须要先运行lockerd并且保证不中途退出。经过测试，如果lockerd中途退出再重新运行的话，因为locklist是保存在内存里会丢失的。结果就会出现之前的lockersh还在执行(他已经获得了lock，在unlock之前不会再和server通信的)，之后再启动的新lockersh会在新lockerd上又获得一次lock的情况……

后一个Schedule::Load则可以根据集群设备的loadavg，top等，决定在哪台设备上运行job。还没测试。之后再记录。

补充：贴一个脚本，仿照lockersh改写的squid集群重启及报警控制：
```perl
#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::Bin/../lib";

use strict;
use warnings;
use autodie;
use vars qw ($Debug);
use Furl;
use IO::File;
use Getopt::Long;

use IPC::Locker;
use IPC::PidStat;

#======================================================================

my $pscount = `ps aux|grep -v grep|grep $0|wc -l`;
print "Already run, waiting for lock now" and exit unless $pscount == 1;

#======================================================================

my %server_params = (lock=>[]);
my $cluserv;

$Debug = 0;
Getopt::Long::config ("require_order");
if (! GetOptions (
                  "dhost=s"     => sub {shift; $server_params{host} = shift;},
                  "cluster=s"   => sub {shift; push @{$server_params{lock}}, split(':',shift);},
                  "port=i"      => sub {shift; $server_params{port} = shift;},
                  "timeout=i"   => sub {shift; $server_params{timeout} = shift;},
                  "verbose!"    => sub {shift; $server_params{verbose} = shift;},
                  "debug"       => \&debug,
                  "service=s"   => \$cluserv,
                  )) {
    die "%Error: Bad usage, see lockersh --help\n";
}

$#{$server_params{lock}}>=0 or die "%Error: --cluster not specified; see lockersh --help\n";

# Fork once to start parent process
my $foreground_pid = $$;  # Unlike most forks, the job goes in the parent

# Do this while we still have STDERR.
my $lock  = new IPC::Locker (verbose=>0,
                             timeout=>0,
                             autounlock=>1,
                             destroy_unlock=>0,
                             %server_params,
                             );
$lock or die "%Error: Did not connect to lockerd,";
$lock->lock;

if (my $pid = fork()) {  # Parent process, foreground job
    print "\tForeground: $cluserv\n" if $Debug;
    # The child forks again quickly.  Sometimes, SIG_CHLD leaks to us and
    # wrecks the exec'd command, so wait for it now.
    my $rv = waitpid($pid, 0);
    if ($rv != $pid) {
        die "%Error: waitpid() returned $rv: $!";
    } elsif ($?) {
        die "%Error: Child process died with status $?,";
    }

    print "Exec in $$\n" if $Debug;
    &service($cluserv);
}
#else, rest is for child process.

# Disassociate from controlling terminal
POSIX::setsid() or die "%Error: Can't start a new session: $!";

# Change working directory
chdir "/";
open(STDIN,  "+>/dev/null") or die "%Error: Can't re-open STDIN: $!";
if (!$Debug) {
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");
}
# Prevent possibility of acquiring a controlling terminal
exit(0) if fork();

# Wait for child to complete.  We can't waitpid, as we're not the parent
while (IPC::PidStat::local_pid_exists($foreground_pid)) { sleep 1; }
print "Parent $foreground_pid completed\n" if $Debug;

# Unlock
$lock->unlock; $lock=undef;
print "Child exiting\n" if $Debug;

sub debug {
    $Debug = 1;
    $IPC::Locker::Debug = 1;
}

sub service {
    my $cluserv = shift;
    die "Only support squid now!" unless $cluserv eq "squid";
    die "Reload failed. Check squid.conf!" if eval "${cluserv}_reload";
    while (1) {
        my $hit_rate = eval "${cluserv}_check";
        notify "HIT Ratio: ${hit_rate}% now.\n";
        exit if $hit_rate > 50;
        sleep 300;
    };
}

sub squid_check {
    my $hit_rate;
    print "Run squid_check" if $Debug;
    my $squid_port = `awk '/^http_port/{print $2}' /etc/squid/squid.conf`;
    open my $fh, "squidclient -p ${squid_port} mgr:info |";
    while (<$fh>) {
        next unless /^\s+Request Hit Ratios:\s+5min:\s*(-?\d+\.\d)%,/;
        print "regex $1" if $Debug;
        $hit_rate = $1;
        last;
    }
    close $fh;
    return $hit_rate;
}

sub squid_reload {
    print "Reload squid daemon. Do not reload within 10 mins of squid start" if $Debug;
    system("squid", "-k", "reconfigure");
    return $?;
}

sub notify {
    my $furl = Furl->new(agent => "Clustrol/0.1");
    $furl->post("http://monitor.domain.com/eml/",
        [ data => "$_" ],
    );
}

__END__
```
