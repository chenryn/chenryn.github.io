---
layout: post
title: 端口转发
date: 2010-01-28
category: linux
tags:
  - iptables
  - perl
---

常见的linux端口转发，是iptables方式，方法如下：
{% highlight bash %}
#modprobe iptable_nat
#modprobe ip_conntrack
#service iptables stop
#echo 1 > /proc/sys/net/ipv4/ip_forward
#iptables -t nat -I PREROUTING -p tcp --dport 443 -j DNAT --to 1.2.3.4
#iptables -t nat -I POSTROUTING -p tcp --dport 8081 -j MASQUERADE
#service iptables save
#service iptables start
{% endhighlight %}
其次网上有不少推荐rinetd，方法如下：
{% highlight bash %}
#wget http://www.boutell.com/rinetd/http/rinetd.tar.gz
#tar zxvf rinetd.tar.gz
#cd rinted
#./configure && make && make install
# cat /etc/rinetd.conf
0.0.0.0 443 www.test.com 443 allow *.*.*.*
logfile /var/log/rinetd.log
{% endhighlight %}
看起来比iptables有个优势，可以采用域名解析，可惜做不到根据域名的不同，把相同端口的请求转向不同IP，其实也就跟直接写IP没多少区别了。
第三还有ssh的端口转发，其实是把原TCP端口的数据转由ssh通道传输。方法如下：
本地转发：ssh -g -L <local
port>:<remote
host>:
远程转发：ssh -g -R <local
port>:<remote
host>:
不过客户未必（或许说基本不可能）给外人开放ssh吧~~
第四，socket网络编程实现。我在网上发现了相关的perl脚本。
例一代码如下：
{% highlight perl %}
#!C:Perlbinperl.exe
#端口重定向(fork、IO::Select）
#By shanleiguang@gmail.com, 2005/10
use strict;
use warnings;
use IO::Socket;
use IO::Select;
use Getopt::Std;
use POSIX qw(:sys_wait_h strftime);
use constant FOREVER => 1;
use constant BUFSIZE => 4096;
#父进程下处理僵死子进程
sub zombie_reaper {
while(waitpid(-1, WNOHANG) > 0) {}
$SIG{CHLD} = &zombie_reaper;
}
$SIG{CHLD} = &zombie_reaper;
#处理参数
my %opts;
getopts('h:l:t:p:', %opts);
print_help() and exit if(defined($opts{'h'}));
print_help() and exit if(not defined($opts{'t'}) or not defined($opts{'p'}));
print_help() and exit if($opts{'t'} !~ m/^d+.d+.d+.d+$/);
print_help() and exit if($opts{'l'} !~ m/^d+$/);
print_help() and exit if($opts{'p'} !~ m/^d+$/);
my $listen_port = (defined($opts{'l'})) ? $opts{'l'} : 8080;
my $target_ip   = $opts{'t'};
my $target_port = $opts{'p'};
#在本地创建监听Socket
my $socket_listen  = IO::Socket::INET->new(
LocalPort => $listen_port,
Proto     => 'tcp',
Listen    => 5,
Reuse     => 1,
);
print timestamp(), ", listening on port $listen_port ...n";
#新建两个用于Socket IO监视的IO::Select对象
my $readers = IO::Select->new();
my $writers = IO::Select->new();
$readers->add($socket_listen);
#父进程仅监视Listening Socket的accept事件
while(FOREVER) {
my @readers = $readers->can_read;
foreach my $reader (@readers) {
if($reader eq $socket_listen) {
#创建子进程处理后续的转发，父进程继续监视Listening Socket
fork and next;
my $socket_client = $socket_listen->accept();
#在子进程中，不再需要对Listening Socket进行操作
$readers->remove($socket_listen);
$socket_listen->close();
#子进程
as_server($socket_client);
exit;
}
}
}
#子进程
sub as_server {
my $socket_client = shift;
my $client_port = $socket_client->peerport();
my $client_ip   = $socket_client->peerhost();
#创建到目标地址:端口的Socket连接
my $socket_forward = IO::Socket::INET->new(
PeerAddr => $target_ip,
PeerPort => $target_port
);
print timestamp(), ", $client_ip:$client_port$target_ip:$target_port.n";
#监视socket_client、socket_forward的IO情况
$readers->add($socket_client);
$readers->add($socket_forward);
$writers->add($socket_client);
$writers->add($socket_forward);
my ($rbuffer_forward, $rbuffer_client) = ('', '');
while(FOREVER) {
my @readers = $readers->can_read;
foreach my $reader (@readers) {
my $rbuffer;
#当socket_client可读时，将读取的内容追加到rbuffer_client后
#假如读取失败，则退出子进程
if($reader eq $socket_client) {
exit if(not recv($reader, $rbuffer, BUFSIZE, 0));
$rbuffer_client.= $rbuffer;
}
#当socket_forward可读时，将读取的内容追加到rbuffer_forward后
#假如读取失败，则退出子进程
if($reader eq $socket_forward) {
exit if(not recv($reader, $rbuffer, BUFSIZE, 0));
$rbuffer_forward .= $rbuffer;
}
}
my @writers = $writers->can_write;
foreach my $writer (@writers) {
#当socket_client可写，且rbuffer_forward不为空时，将rbuffer_forward
#内容写入socket_client，假如写失败，则退出子进程
if($writer eq $socket_client) {
next if(not $rbuffer_forward);
exit if(not send($writer, $rbuffer_forward, 0));
$rbuffer_forward = '';
}
#当socket_forward可写，且rbuffer_client不为空时，将rbuffer_client
#内容写入socket_forward，假如写失败，则退出子进程
if($writer eq $socket_forward) {
next if(not $rbuffer_client);
exit if(not send($writer, $rbuffer_client, 0));
$rbuffer_client = '';
}
}
}
}
sub timestamp {
return strftime "[%y/%m/%d,%H:%M:%S]", localtime;
}
sub print_help {
my $filename = (split /\/, $0)[-1];
print <<HELP
>>>
$filename [-h,-l:]
 -h  print help
 -l  listening local port, default 8080
 -t  target ipaddr
 -p  target port
By shanleiguang@gmail.com, 2005/10
HELP
}
{% endhighlight %}
例二代码如下：
{% highlight perl %}
#!C:Perlbinperl.exe
#端口重定向（POE）
#By shanleiguang@gmail.com, 2005/10
#POE结构：
#
#Driver->Filter->Wheel->Components
#
|______|______|________|
#
|
#          Session
#
|
# Kernel
#
#Driver：    底层文件操作的抽象，在编程时不会直接用到
#Filter：    底层、中层协议操作的抽象，通常不会直接用到
#Wheel：     高层协议操作的抽象，经常要用到
#Components：POE提供的一些拿来就能用的组件
#Session：   会话抽象，会话中需要创建高层协议抽象
#Kernel：    POE管理会话的内核
#
#POE对象的数据结构：
#
#$_[HEAP]：是会话唯一的数据存储区；
#$_[SESSION]：是指向会话自身的引用；
#$_[KERNEL]：是指向会话管理内核的引用；
#@_[ARG0..ARG9]：用于传递给各事件处理函数的参数；
#
#还是实例最直观：
#在父会话中创建一个监听用的Socket，当有客户端连接，即有accept_sucess事件发生时，
#则创建一个子会话处理后续事件，并将accept获得的客户端Socket传递给子会话；子会话
#创建到目标的Socket，连接过程中，如果客户端Socket中有input事件，则将客户端的input
#内容缓存在一个队列中，当连接成功后，发送给到目标的那个Socket中，见下图：
#
#          +-------------------------------+
#         /|      Socket_listen            |
#        / +-------------------------------+
#Client|Socket_client Socket_server|Target
#          +-------------------------------+
#                    Forwarder
use strict;
use warnings;
use Socket;
use Getopt::Std;
use POSIX qw(strftime);
use POE qw(
Wheel::SocketFactory
Wheel::ReadWrite
Filter::Stream
);
#Get Options
my %opts;
getopts('hl:t:p:', %opts);
print_help() and exit if(defined($opts{'h'}));
print_help() and exit if(not defined($opts{'t'}) or not defined($opts{'p'}));
print_help() and exit if($opts{'t'} !~ m/^d+.d+.d+.d+$/);
print_hekp() and exit if($opts{'p'} !~ m/^d+$/);
my $listen_port = (defined($opts{'l'})) ? $opts{'l'} : 8080;
my $target_addr = $opts{'t'};
my $target_port = $opts{'p'};
###Create Parent - 'Listen Session'###
###创建父会话用于监听客户端的连接
###会话创建的最后将进入_start状态，执行_start的handler
###accept_success即在_start的handler中创建监听Socket的Wheel中
###的SuccessEvent事件，它的handler是forwarder_create函数
###$_[ARG0]是wheel::SocketFatory的SuccessEvent传递的参数
POE::Session->create(
  inline_states => {
    _start => &forwarder_server_start,
    _stop  => sub { print timestamp(), ", forwarder server stopped."; },
    accept_success => sub { &forwarder_create($_[ARG0]); },
    accept_failure => sub { delete $_[HEAP]->{server_wheel} },
  },
);
$poe_kernel->run();
exit;
###Event handlers for Parent Session###
###父会话中的事件处理函数
sub forwarder_server_start {
print timestamp(), ", listening on port $listen_port and ";
print "forward to $target_addr:$target_port\n";
#在父会话的存储区创建一个监听Socket类型的Wheel
$_[HEAP]->{server_wheel} = POE::Wheel::SocketFactory->new(
  BindPort       => $listen_port,
  SocketProtocol => 'tcp',
  ListenQueue    => SOMAXCONN,
  Reuse          => 'on',
#ARG0 of SuccessEvent
  SuccessEvent   => 'accept_success',
  FailureEvent   => 'accept_failure',
);
}
###Create Child - 'Forward Session'###
###创建子会话
sub forwarder_create {
my $socket = shift;
POE::Session->create(
inline_states => {
_start => &forwarder_start,
_stop  => sub {
print ' ' x 4, timestamp(), ', sessionId:';
print $_[SESSION]->ID, ", forwarder stop\n";
},
client_input => &client_input,
client_error => sub {
delete $_[HEAP]->{wheel_client};
delete $_[HEAP]->{wheel_server};
},
server_connect => &server_connect,
server_input => sub {
$_[HEAP]->{wheel_client}->put($_[ARG0]) if(exists $_[HEAP]->{wheel_client});
},
server_error => sub {
delete $_[HEAP]->{wheel_client};
delete $_[HEAP]->{wheel_server};
},
},
#Parameters to '_start' Event
args => [$socket],
);
}
##Event Handlers of Child Session##
sub forwarder_start {
my ($heap, $socket) = @_[HEAP, ARG0];
print ' ' x 4, timestamp(), ', sessionId:';
print $_[SESSION]->ID, ", forwarder startn";
#Buffer client's input while connecting to the target
$heap->{state} = 'connecting';
$heap->{queue} = [];
#ClientForwarder server
$heap->{wheel_client} = POE::Wheel::ReadWrite->new(
Handle => $socket,
Driver => POE::Driver::SysRW->new(),
Filter => POE::Filter::Stream->new(),
InputEvent => 'client_input',
ErrorEvent => 'client_error',
);
#Forwarder servertarget
$heap->{wheel_server} = POE::Wheel::SocketFactory->new(
RemoteAddress => $target_addr,
RemotePort    => $target_port,
SuccessEvent  => 'server_connect',
FailureEvent  => 'server_error',
);
}
sub server_connect {
my ($kernel, $session, $heap, $socket) = @_[KERNEL, SESSION, HEAP, ARG0];
#Replace
$heap->{wheel_server}
$heap->{wheel_server}
= POE::Wheel::ReadWrite->new(
Handle     => $socket,
Driver     => POE::Driver::SysRW->new,
Filter     => POE::Filter::Stream->new,
InputEvent => 'server_input',
ErrorEvent => 'server_error',
);
$heap->{state} = 'connected';
$kernel->call($session, 'client_input', $_) foreach(@{$heap->{queue}});
$heap->{queue} = [];
}
sub client_input {
my ($heap, $input) = @_[HEAP, ARG0];
push @{$heap->{queue}}, $input and return if($heap->{state} eq 'connecting');
$heap->{wheel_server}->put($input) if(exists $heap->{wheel_server});
}
#Common subroutines
sub timestamp {
return strftime "[%H:%M:%S]", localtime;
}
sub print_help {
my $filename = (split /\/, $0)[-1];
print <<HELP
>>>
$filename [-h,-l:]
-h  print help
-l  listen port
-t  target ipaddress
-p  target port
A simple TCP forwarder server, 2005/10
By shanleiguang@gmail.com
HELP
}
{% endhighlight %}
使用方法：
# perl tcpForwarder.pl -l 8080 -t
xxx.xxx.xxx.xxx -p 80
[xx:xx:xx:], listening on local port 8080 and forward to
xxx.xxx.xxx.xxx:80...
...


