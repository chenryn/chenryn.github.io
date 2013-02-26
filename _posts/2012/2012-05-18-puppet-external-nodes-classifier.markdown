---
layout: post
title: 【puppet系列】puppet使用ENC定义节点
date: 2012-05-18
category: puppet
tags:
  - perl
---

今天研究puppet dashboard。主要有ENC和reports两个功能。其中ENC功能相当扯淡，因为你在web上点击添加的class/node/group，是没有任何依赖性检查(比如node命名是否符合fqdn，class是否存在)的，随便咋填绝无报错和拒绝！而且也没有提供类似report的导入工具，一旦启用就要完全重新手工输入所有配置……所以无论是从导入角度还是管理角度，自己实现一个靠谱点的ENC都是有必要的。    
关于puppet的ENC配置，参见[ENC的文档](http://docs.puppetlabs.com/guides/external_nodes.html)    
主要就是修改puppet.conf里两个配置：    
node_terminus，由plain修改成exec；external_nodes，由none修改为ENC脚本的路径。    
类似如下：
    [master]    
    node_terminus = exec    
    external_nodes = /etc/puppet/webui/external_nodes    
脚本输入输出的说明：    

    Its only argument is the name of the node to be classified, and it returns a YAML document describing the node.

注意到此为止配置修改不算结束！文档中提到，puppet是支持同时开启ENC和site.pp配置的。puppet会自动merge两个配置。但是debug运行时可以看到，这个merge是按照node级别进行的。也就是说：    

1. puppet master收到一个node的请求，如果node_terminus配置为exec，输出node的fqdn给external_nodes；    
2. 收到external_nodes的返回，为一个yaml体或者空；    
3. 加载site.pp，这是按照文本顺序进行的。如果都是import "module"，那么最后就进入module的parameter和template处理。    
4. 如果碰到import "node/*.pp"这样的配置，则开始加载node/*.pp中的node配置；    
5. 如果node/*.pp中的node在当前的node object中不存在，那么新建这个object。    
6. 如果已经存在，那么覆盖为后来的这个node配置。    

所以为了方便起见，请删除掉site.pp中的import "node/*.pp"这行配置。我在这里就被郁闷了很久。

然后是我这里的想法是尽量不更改pp的语法，只是提供一个把group里的ip到fqdn的转化然后查找cluster配置组合成yaml。    
也就是说有一个group的配置目录，其配置文件为"groupname.pp"，内容如下：
{% highlight ruby %}
group "groupname" {
    $string = "test"
    $arrays = [123, abc]
    include module1, module2
}
{% endhighlight %}
还有一个iplist的配置目录，其配置文件为“groupname.iplist”，内容如下：
{% highlight squid %}
1.2.3.4
2.3.4.5
{% endhighlight %}
那么以后服务器组有啥变更，只需要修改一下iplist就好了，不用重启puppet进程。    

所以有两个脚本，一个是external_node脚本：    
{% highlight perl %}
#!/bin/env perl
use warnings;
use strict;
use autodie;
use DBI;
use YAML::Syck;

my $base_dir = "/etc/puppet/webui";

my $node = $ARGV[0];
my $group = sqlite_select($node);
my $hash = pp2hashref($group);
print Dump($hash);
# ENC要求退出值必须为0 
exit 0;

sub pp2hashref {
    my $group = shift;
    my $data = {};
    open my $fh, '<', "${base_dir}/group/${group}.pp";
    my $i;
    while(<$fh>) {
        if ( /^#|^\s*$|}$/ ) {
            next;
        } elsif ( /^group\s+"(\w+)"/ ) {
            die "group name do not match,check please!" unless $1 =~ m/$group/i;
        } elsif ( /^\s*?\$(\w+)\s*=\s*"(.+)"$/ ) {
            $data->{"parameters"}->{"$1"} = $2;
        } elsif ( /^\s*?include\s+(.+)$/ ) {
            @{$data->{"classes"}} = split(/,\s*/, $1);
        } elsif ( /^\s*\$(\w+)\s*=\s*\[([^]]+)]?/ ) {
            $i = $1;
            grep { push @{$data->{"parameters"}->{"$i"}}, $_ } split(/,\s*/, $2);
        } elsif ( /^\s*([^]]+)]?/ ) {
            grep { push @{$data->{"parameters"}->{"$i"}}, $_ } split(/,\s*/, $1);
        } else {
            next;
        };
    };
    $data->{"parameters"}->{"clustername"} = $group;
    # ENC要求输出的yaml中必须提供environment参数 
    $data->{"environment"} = "production";
    return $data;
}

sub sqlite_select {
    my $node = shift;
    my $dbh = DBI->connect("dbi:SQLite:dbname=${base_dir}/node_info.db","","",{RaiseError=>1,AutoCommit=>0});
    my $sth = $dbh->prepare("select node_group from node_info where node_fqdn = ?");
    $sth->execute("$node");
    my $ret = $sth->fetchrow_hashref->{"node_group"};
    $dbh->disconnect();
    return $ret;
};
{% endhighlight %}
一个是维护sqlite的脚本：
{% highlight perl %}
#!/bin/env perl
use warnings;
use strict;
use autodie;
use DBI;
use Net::Nslookup;


my $base_dir = "/etc/puppet/webui";

sqlite_update();

sub ip_conv {
    my $ip = shift;
    my $name = nslookup(host => "$ip", type => "PTR");
    # ENC的输入参数为全小写格式，所以sqlite中也必须存储小写格式的主机名 
    return lc($name);
};

sub sqlite_rebuild {
    # 配置系统变动不大，且puppet本身还有一层也是用sqlite的node配置缓存层，
    # 所以这里不用复杂的select判断再update或者insert，直接重建sqlite 
    unlink "${base_dir}/node_info.db";
    my $dbh = DBI->connect("dbi:SQLite:dbname=${base_dir}/node_info.db","","",{RaiseError=>1,AutoCommit=>0});
    my $sql = 'create table node_info (node_fqdn, node_group)';
    $dbh->do($sql);
    # sqlite支持简单事务，所以要即时提交 
    $dbh->commit();
    my $sth = $dbh->prepare('replace into node_info values(?,?)');
    my @groups = grep { s/^${base_dir}\/iplist\/(\w+?).list$/$1/ } glob("${base_dir}/iplist/*");
    print $_,"\n" for @groups;
    foreach ( @groups ) {
        my $group = $_;
        open my $fh, '<', "${base_dir}/iplist/${group}.list";
        while (<$fh>) {
            my $fqdn = ip_conv($_);
            $sth->execute("$fqdn", "$group");
            die $DBI::errstr if $dbh->err();
        };
    };
    $dbh->commit();
    $dbh->disconnect();
};
{% endhighlight %}
以上是ENC的配置。继续分析puppet dashboard，除了ENC外，另一个功能就是reports，相比ENC来说，reports功能还算稍微靠谱一点，用http方式替换puppet自身的store方式，并存数据在mysql里。目前使用dashboard的人主要也就是在用这个功能。    
但是我个人认为，一般情况下运维不可能专门开一个页面看着puppet，也不太会有必要按照时间段查看状态报表汇总图这个东东，真正要紧的，是及时接到运行错误的报警以便上机处理。所以这里最后是一个监控reports的脚本，目前还没看到http方式的reports数据格式，所以暂时继续使用store的方式，然后采用Linux文件系统的inotify方式报警。
{% highlight perl %}
#!env perl
use strict;
use warnings;
use YAML::Syck;
use AnyEvent::Filesys::Notify;
use EV;

# 使用AE的这个扩展而不直接用Linux::Inotify2模块，方便万一之后迁移到BSD主机
# 而且异步回调的方式性能更好，在压力较大时不会阻塞丢失事件 
my $notifier = AnyEvent::Filesys::Notify->new(
    dirs     => [qw(/var/lib/puppet/reports)],
    interval => 0.5,
    # 在puppetd请求的时候，会在目录下先生成临时文件，完成后再mv成正式的，所以要过滤
    filter   => sub { shift =~ /\.yaml$/ },
    cb       => sub {
        for ( @_ ) {
            # 一般这里会是两个type，创建的created和修改的modified，因为文件名只精确到分钟，如果两次运行在一分钟内，文件名就一样
            if ( $_->type ) {
                my $file = $_->path;
                my $logs = LoadFile($file)->{'logs'};
                for ( @{$logs} ) {
                    if ( $_->{'level'} eq 'err' ) {
                        process($file, $_->{'message'});
                    };
                };
            };
        };
    },
);

EV::loop();

sub process {
    my ( $path, $message ) = @_;
    if ( $path =~ m/\/([^\/]+)\/\d{12}\.yaml$/ ) {
        # 这里用nagios还是email方式处理都可以，代码略
        print $1," has err: ",$message,"\n";
    };
};

{% endhighlight %}

