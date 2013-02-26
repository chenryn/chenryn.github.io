---
layout: post
title: 学习pm和bless的写法
date: 2011-05-12
category: perl
---

考虑到公司环境必须先rsa_auth再su的问题，一般的pssh啊mussh啊sshbatch啊，都不能直接用，决定把上篇脚本里的相关部分抽出来成为一个模块，借机学习一下package和bless的简单概念：
{% highlight perl %}
#包名，如果做pm的话，必须和(.*).pm的名字一样
package raocl;
use Parallel::ForkManager;
use Expect;
#Exporter模块是perl提供的导入模块方法的工具
use base 'Exporter';
#Exporter有两个数组，@EXPORT里存的是模块的sub，@EXPORT_OK里存的是模块的var；
#使用模块时只能调用这些数组里有定义的东西
our @EXPORT = qw/new cluster/;
#一般模块都有一个new方法来进行初始化定义
sub new {
#所有sub传入的第一个参数都是本身，所以要先shift出来，然后才是脚本显式传入的参数
my $class = shift;
#将参数转成哈希方式，并返回一个引用；
#正规做法应该在这里指定一些必须要有的参数，比如passwd => %args{'passwd'} || '123456'
my $self = {@_};
#bless上面返回的哈希引用到自己，再传递出去；以后在这之外的地方，使用被bless过的$self时自动就关联上new里的数据了。
#这里我写的极简单，看比较正式的模块写发，这里对$class还要用ref();判断是不是引用等
return bless $self,$class;
}

sub cluster {
#这里的$self就是上面被bless过的了
    my ($self, $command) = @_;
    my %remote_result;
    my $pm = Parallel::ForkManager->new( $self->{fork}, '/tmp/');
    $pm->run_on_finish (
    sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $reference) = @_;
        if (defined($reference)) {
            my @data = @$reference;
            $remote_result{"$data[0]"} = $data[1];
        } else {
            print qq|No message received from child process $pid!\n|;
        }
    }
    );
#直接使用bless过的$self解引用出来的hosts列表
foreach my $remote_host (@{$self->{hosts}}) {
    $pm->start and next;
#使用bless过的$self的sub完成expect功能
    my @check = ($remote_host, $self->pexpect($remote_host, $command));
    $pm->finish(0, \@check);
}
$pm->wait_all_children;

return %remote_result;
}

sub pexpect {
#还是同样的$self，然后才是上面调用时传递的$host和$shell
my ($self, $host, $shell) = @_;
#使用new里提供的passwd
my $password = $self->{passwd};
my $exp = Expect->new;
$exp = Expect->spawn("ssh -l admin -i /usr/local/admin/conf/id_rsa -o ConnectTimeout=5 $host");
$ENV{TERM}="xterm";
$exp->raw_pty(1);
#使用new里提供的开关
$exp->exp_internal("$self->{debug}");
$exp->log_stdout("$self->{output}");
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
#因为shell命令执行的输出可能有滞后，所以将前后都输出
my $read = $exp->before() . $exp->after();
$read =~ s/\[.+\@.+\]//;
$exp->send("exit\n") if ($exp->expect(undef,'$'));
$exp->soft_close();
return $read;
}
#package结尾，必须return一个1，原因未知……
1;{% endhighlight %}
使用如下：
{% highlight perl %}#!/usr/bin/perl -w
#可以在/usr/lib/perl5下，也可以在pl脚本的同目录下
use raocl;
#从文件中读取host列表为数组
open FH, "./list";
my @hosts = <FH>;
#使用new初始化，传递host列表的引用给函数
$raocl=new raocl(hosts=>\@hosts,
    fork => '10',
    output => 0,
    debug  => 0,
    passwd => '123456',);
%result = $raocl->cluster("$shell");
foreach my $host (keys %result) {
    print $host."\t".$result{$key},"##############\n";
};{% endhighlight %}
