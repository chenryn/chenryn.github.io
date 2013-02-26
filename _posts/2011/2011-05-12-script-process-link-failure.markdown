---
layout: post
title: 链路故障应急处理脚本
date: 2011-05-12
category: monitor
tags:
  - perl
---

话接上篇，继续完成这个perl脚本。花了今天一天的时间，基本定稿如下：
{% highlight perl %}#!/usr/bin/perl -w
use Net::Ping::External qw(ping);
use Tie::File;
use Getopt::Long;

Getopt::Long::Configure ("bundling");
GetOptions(
     'H:s' => \$ct_host,  'host:s'   => \$ct_host,
     'T:i' => \$time,     'time:i'   => \$time,
     'N:i' => \$fork_num, 'number:i' => \$fork_num,
     'h'   => \$help,     'help'     => \$help,
);

if( $help ) {
    print "Usage: ping_check.pl -H 10.168.168.251 -T 30 -N 10\n";
    print "       -H/host:   The switch ip address to be checked in china telecom;\n";
    print "       -T/time:   The seconds used for pinging;\n";
    print "       -N/number: The number of fork processes to expect the remote hosts;\n";
    print "       -h/help:   The usage just you see now.\n";
    exit 0;
}

my $mark_file = '/tmp/mark_file';
my @last;

my $result = ping( hostname => "$ct_host",
                   count    => $time * 5,
                   size     => '128',
                   timeout  => '1',
#原生的Net::Ping模块需要自己while来控制sleep；
#现在采用的Net::Ping::External是直接调用的外部ping命令，但默认也没有-i参数；
#package中sub ping{}里把未定义的@_都给到了%args，
#所以只需要在199行（即sub _ping_linux{}中）添加上-i $args{interval}就能用了。
                   interval => '0.2',
                 );
#用tie将数组@last锁定到文件上——我曾经想过直接锁个变量，但是似乎没有，只能数组或哈希？
tie @last, 'Tie::File', $mark_file or die $!;

if ( $result && ($last[0] == 1) ) {
    print "ok\n";
}
elsif ( $result && ($last[0] == 0) ) {
    print "Beginning recovery\n";
    &parallel_manage("recovery", "$fork_num");
    &sms_alarm('CNC recovery peer to intranet');
    &email_alarm('CNC recovery peer to intranet');
} else {
    print "Error! Beginning change to template configuration\n";
    &parallel_manage("change", "$fork_num");
    &sms_alarm('CNC change peer to CT');
    &email_alarm('CNC change peer to CT');
}

$last[0] = $result;
untie @last;

sub email_alarm {
    use Net::SMTP_auth;
    my $email_message = shift;
    my $smtp = Net::SMTP_auth->new( Host    => 'smtp.domain.com',
                                    Timeout => '30',
#                                    Debug   => '1',
                              );
    $smtp->auth('LOGIN', 'alarm@domain.com', 'password');
    $smtp->mail('alarm@domain.com');
    $smtp->to( 'netadmin@domain.com' );
    $smtp->data();
    $smtp->datasend("To: Netadmin\@domain.com\n");
    $smtp->datasend("\n");
    $smtp->datasend("${email_message}\n");
    $smtp->dataend();
    $smtp->quit;
}

sub sms_alarm {
    use Net::MySQL;
    my $sms_message = shift;
    my %contacts = &get_contacts();
    my $mysql = Net::MySQL->new( hostname => '10.1.1.45',
                                 database => 'smsd',
                                 user     => 'smsd',
                                 password => 'smsd',
                               );
    foreach my $send_number (values %contacts) {
        $mysql->query(
            "INSERT INTO outbox (number, text) VALUES ( $send_number, '$sms_message')"
        );
    }
    $mysql->close;
}

sub parallel_manage {
#因为Expect模块本身使用了fork();要求运行在主进程中，所以在并发的时候不能采用多线程而得用多进程
    use Expect;
    use Parallel::ForkManager;

    my $command = shift || 'id';
    my $max_fork = shift || '10';
    my @remote_list = ('10.1.1.64',
                       '10.1.1.50',
                       '10.1.1.35',
                      );
    my $remote_host;
    my %remote_result;
    my $pm = Parallel::ForkManager->new( $max_fork, '/tmp/');
#采用Parallel::ForkManager模块时，如果需要子进程返回数据结果给父进程，必须把run_on_finish()放在fork之前
#Parallel::ForkManager模块实际上是采用文件存储的方式进行父子进程的数据通信，所以上面new的时候定义一个临时文件路径
    $pm->run_on_finish (
        sub {
#主要有用的是子进程pid，子进程退出状态，返回数据的引用
            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $reference) = @_;
            if (defined($reference)) {
#解引用后复制到数组并转存成哈希
                my @data =  @$reference;
                $remote_result{"$data[0]"} = $data[1];
            } else {
                print qq|No message received from child process $pid!\n|;
            }
        }
    );

    foreach $remote_host (@remote_list) {
        $pm->start and next;
        my @check = ($remote_host, &ssh_expect($remote_host, $command));
#默认参数就是finish(0);需要返回数据时才加上引用
        $pm->finish(0, \@check);
    }
    $pm->wait_all_children;
    foreach my $key (sort keys %remote_result) {
        print $remote_result{$key},"\n";
    }
}

sub ssh_expect {
    my ($host, $shell) = @_;
    my $exp = Expect->new;
    my $password = 'password';
    $exp = Expect->spawn("ssh -l monitor -i /usr/local/monitor/conf/id_rsa -o ConnectTimeout=5 $host");
#    $ENV{TERM}="xterm";
#    $exp->exp_internal(1);
    $exp->raw_pty(1);
#关闭输出，不然expect会把整个session都print出来（实际是到STDERR）
    $exp->log_stdout(0);
    $exp->expect(2,[
                    '\$',
                    sub {
                            my $self = shift;
                            $self->send("su -\n");
                        }
                   ],
                   [
                    '\(yes/no\)\?',
                    sub {
                            my $self = shift;
                            $self->send("yes\n");
			    exp_continue;
                         }
                   ]
               );

    $exp->expect(2, [
		    'Password:',
		    sub {
			    my $self = shift;
			    $self->send("${password}\n");
			    exp_continue;
		        }
		   ],
		   [
		    '#',
		    sub {
			    my $self = shift;
			    $self->send("${shell}\n");
			}
		   ]
	       );
    $exp->send("exit\n") if ($exp->expect(undef,'#'));
#expect有before/match/after来返回相应的数据
    my $read = $exp->before();
    $exp->send("exit\n") if ($exp->expect(undef,'$'));
    $exp->soft_close();
    return $read;
}

sub get_contact {
    open my FH, "/usr/local/nagios/etc/objects/contacts.cfg";
    my %hash;
    local $/ = 'define';
    while(<FH>) {
        next unless /pager\s+(\d{11})/;
        my $sms_num = $1;
        $hash{$1}=$sms_num if /email\s+([a-z\.]+?)\@bj.china.com/;
    }
    return %hash;
}
{% endhighlight %}
