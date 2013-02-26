---
layout: post
title: perl的Expect模块
date: 2011-05-09
category: perl
---

手头一批机器，因为历史的原因，有些密码登录、有些密钥登录，有些wheel组免密码su - root、有些又不行。为了统一管理操作，得想办法找一个能适应这四种情况的自动登录方法。

先看的Net::SSH2模块，用户、主机、密钥都支持列表，也有$ssh-&gt;exec();，但是最后这步su - root密码还是没法完成；
然后看的Net::SSH::Expect模块，其实就是在Expect模块外面加一层shell调用ssh命令。没有独立的参数指定密钥等，而是写在ssh_option=&gt;' -i id_rsa '里，更糟糕的情况是：在无密码登陆时，只能使用$ssh-&gt;run_ssh();而不能用$ssh-&gt;login();——但关于初次登陆的(yes/no)?的问题，却只在login()里有处理，run_ssh()里没有！可以修改Net/SSH/Expect.pm文件，在sub run_ssh()的return之前添加相关处理的语句：
{% highlight perl %}
$exp->expect(1,
[ qr/\(yes\/no\)\?\s*$/ => sub { $exp->send("yes\n"); exp_continue; } ],
);{% endhighlight %}
但运行的时候，一台内网机器，完成一次su -后ls的操作，居然平均需要消耗3s的时间。
于是干脆使用原版的Expect模块，平均单次运行时间缩短到了1.3s，如下：
{% highlight perl %}
#!/usr/bin/perl -w
use Expect;
#本来还打算用cgi模块改成web界面的，但运行时不时爆出“(70007)The timeout specified has expired:
#ap_content_length_filter: apr_bucket_read() failed”的error_log，
#百度谷歌的各种结果，如$|、STDOUT、Timeout、version都查了一遍，没有结果，只好暂时放弃
#use CGI::Simple;
#my $q = new CGI::Simple;
#my $host = $q->param('host');
#my $command = $q->param('command');
#print $q->header;
my $host = $ARGV[0];
my $command = $ARGV[1];
my $password = '1234!@#$';
my $exp = Expect->new;
$exp = Expect->spawn("ssh -l monitor -i /usr/local/monitor/etc/id_rsa $host");
#Expect模块的debug分析
#$exp->exp_internal(1);
$exp->expect(2, [
                 '\$',
                 sub {
                  my $self = shift;
                  $self->send("su -\n");
                 }
                ],
                [
#凯哥三年前的博客复制的perldoc内容，都没有\号，实际必须有！
#perldoc说不加-re时就是完全匹配，这很容易让人理解为==的效果，但debug告诉我不是这样滴……
#Net::SSH::Expect里sub login()里也用了\号，见上。
                 '\(yes/no\)\?',
                 sub {
                  my $self = shift;
                  $self->send("yes\n");
                  exp_continue;
                  }
                ]
);
$exp->expect(2, [
                 'Password:',
                 sub {
                  my $self = shift;
#perldoc推荐使用$self->send_slow($timeout,"command\r");的方式，不过试了下，好慢啊，算了
                  $self->send("${password}\n");
                  exp_continue;
                  }
                ],
                [
                  '#',
                 sub {
                  my $self = shift;
                  $self->send("${command}\n");
                  }
                ]
);
$exp->send("exit\n") if ($exp->expect(undef,'#'));
$exp->send("exit\n") if ($exp->expect(undef,'$'));
{% endhighlight %}
