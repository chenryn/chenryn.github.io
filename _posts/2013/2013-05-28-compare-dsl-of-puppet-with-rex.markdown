---
layout: post
theme:
  name: twitter
title: puppet和rex的常用资源写法类比
category: devops
tags:
  - rex
  - puppet
---

首先要申明，rex 和 puppet 本质上是不同的，puppet 追求的是状态，rex 追求的是操作。puppet 用户经常关心的是 agent 运行了没，而 rex 用户关心的是怎么写 Rexfile 能让中控运行 rex 时的命令参数更简洁漂亮(个人感受==!)。所以哪怕在本文中列举的这些资源写法很类似，也请读者们注意：rex 的资源关键词命名，都是带有动作性的，比如 `create`，`add`，`install`，`upload`，`download`，`sync` 等等。甚至精确的说，rex 里这些不是资源(`Puppet::Types::***`)，他们是 `Rex::Commands::***`。

因为 rex 基于并发 ssh 连接，所以它有一些操作是 puppet 所没有的，比如 `tail`，`file_append`，`fdisk`，`sysctl` 和 `iptables` 等等，这里暂时不列举。总的来说，本文目的是总结类似的部分，而不是不同的用法……

Cron 资源
==================================

### puppet 写法

```ruby
    cron { 'check_starttime':
        ensure  => present,
        minute  => 30,
        hour    => '*/2',
        user    => 'root',
        command => 'sh /usr/local/bin/check_start_time.sh',
        require => File['/usr/local/bin/check_start_time.sh'],
    }
```

### rex 写法

```perl
    cron add => "root", {
        minute       => '5',
        hour         => '*',
        day_of_month => '*',
        month        => '*',
        day_of_week  => '*',
        command      => '/path/to/your/cronjob',
    };
```

File 资源
==================================

### puppet 写法

```ruby
    file { '/etc/squid/squid.conf':
        ensure    => file,
        mode      => '0755',
        content   => template('squid/squid.conf.erb'),
        require   => Package['squid'],
        subscribe => Service['squid'],
    }
```

### rex 写法

```perl
    file "/etc/squid/squid.conf",
        content   => template("templates/squid.tpl", vars => \%var ),
        owner     => "root",
        group     => "root",
        mode      => 700,
        needs     => SquidPkgTask,
        on_change => sub { service squid => 'restart' };
```

这里的 `on_change` 是 File 资源独有的。

__通用资源方面，rex 中在同一个 task 内，是按照书写顺序执行；在 task 之间，通过 `needs` 可以定义依赖。__

另外 rex 还有 `before`，`after`，`around` 三个关键字作用于 task 上。不过这三个是在 rex 控制端执行，不是在远端主机上执行。

注意这里，这个 file 看起来没有使用操作性的动词，但其实他是下面这个写法的简写而已：

```perl
    install file  => 'templates/etc/hosts.tpl', {
        source    => "/etc/hosts",
        owner     => "root",
        group     => "root",
        mode      => 700,
        on_change => sub { say "Something was changed." },
        template  => {
                        greeting => "hello",
                        name     => "Ben",
                     },
    };
```

另外，还有一个通过 SFTP 接口上传的写法：

```perl
    upload "hosts" => "/etc/";
```


Package 资源
==================================

### puppet 写法

```ruby
    package { 'ganglia-gmond-modules-python-plugin':
        ensure  => installed,
        require => Class['repos'],
    }
```

### rex 写法

```perl
    repository add => myrepo,
        url => 'http://rex.linux-files.org/CentOS/$releasever/rex/$basearch/';
    update_package_db;
    install package => 'vim';
```

Class 定义
==================================

### puppet 写法

```ruby
    class squid {
        include squid::install
    }
```

### rex 写法

rex 执行的 Rexfile 其实就是 perl 的模块文件，所以写法就是标准的 perl 写法。

```perl
    package Squid {
        require Squid::Install;
    }
```

呼呼，新版本的 Perl 中可以用 `{}` 来包裹 package 定义的内容，看起来是不是更像一些？不过 CentOS6 的 5.10 版还不支持，所以通用起见，还是这样写吧：

```perl
    package Squid;
    require Squid::Install;
    1;
```

Directory 资源
==================================

### puppet 写法

```ruby
    file { 'murder-client':
        ensure  => 'directory',
        path    => '/usr/local/murder',
        recurse => true,
        purge   => true,
        source  => 'puppet:///modules/murder/dist',
    }
```

### rex 写法

rex 中采用 rsync 来完成目录文件的同步：

```perl
    mkdir('/usr/local/murder');
    sync 'dist/*' => '/usr/local/murder', {
        exclude    => "*.sw*",
        parameters => '--backup --delete',
    };
```

Shell 资源
==================================

### puppet 写法

```ruby
    exec {'init-reload':
        command     => '/sbin/initctl reload-configuration && /sbin/initctl start svscan',
        subscribe   => File['/etc/init/svscan.conf'],
        refreshonly => true,
    }
```

### rex 写法

```perl
    run "cmd", sub {
        my ($out, $err) = @_;
    };
```

这个回调函数可以不要，那么 `run` 命令返回输出到变量。这种用法在单行命令中最常用，比如这样：

```bash
    rex -H '192.168.0.[10..30]' -e 'say run "df -h"'
```

User/Group 资源
==================================

### puppet 写法

```ruby
    group {'puppet':
        ensure => present,
        gid    => 501,
        system => true,
    }
    user {'puppet':
        ensure => present,
        uid    => 501,
        system => true,
        groups => ['puppet', '...'],
        expiry => '2013-05-30',
        managehome => false,
    }
```

### rex 写法

```perl
    create_group 'puppet', {
        gid    => 501,
        system => 1,
    }
    create_user 'puppet',
       uid => 501,
       home => '/etc/puppet',
       expire => '2013-05-30',
       groups  => ['puppet', '...'],
       password => 'blahblah',
       system => 1,
       no_create_home => TRUE,
       ssh_key => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQChUw...";
```

Service 资源
==================================

### puppet 写法

```ruby
    service {'nginx':
        ensure => true,
        enable => true,
    }
```

### rex 写法

```perl
    service apache2 => ensure => "started";
    service apache2 => "start";
```

再次可见，rex 认为 `service` 命令和 `chkconfig`/`update-rc.d` 命令是两件事情，所以要分开两个写法。

Mount 资源
==================================

### puppet 写法

```ruby
    mount {'/mnt/sda6':
        ensure  => present;
        device  => '/dev/sda6',
        fstype  => 'ext3',
        options => 'noatime,async';
    }
```

### rex 写法

```perl
    mount "/dev/sda6", "/mnt/sda6",
       fs => "ext3",
       options => [qw/noatime async/];
```

Facts 变量和模板
==================================

### puppet 写法

在 puppet 中，Facts 变量有两种用法，一个是 `*.pp` 里的写法：

```ruby
    $::lsbdistid
```

另一种是在 `*.erb` 里的写法，值得注意的是变量的作用域：

```ruby
    <%= scope::lookupvar('ipaddress') %>
    <%= scope::lookupvar('nginx::name') %>
```

### rex 写法

在 rex 中，远端主机的系统状态有多种获取方式，比如：

```perl
    # 全部，这些变量默认会传递给 template
    my $sysinfo = Rex::Helper::System::info;

    # 实际就是从上面info里取具体的变量
    my $lsd = get_operating_system;

    # 这个慎用，会死人的
    my @ns = netstat;
```

也可以使用 `set` 指令，这种变量和使用 perl 标准 `my $name` 方式不同的是它可以直接在模板中读取：

```perl
    set name => 'CDN';
```

至于 rex 的模板，它默认没有使用 CPAN 上任何一种现成的模块，而是自己实现了一个，写法如下：

```perl
    template('your.tpl', yourvars => \%hash );
```

然后在模板中这样引用：

```perl
    My variable is <%= $::yourvars->{key} %>
    My name is <%= $::name %>
    My lsd is <%= $::operatingsystem %>
```

明显有模仿 puppet 的痕迹，传递进模版的变量以 `$::` 开头，个人比较汗……

所以个人建议还是更换成 CPAN 上的流行模板，比如 `Text::Xslate` 或者 `Text::MicroTemplate` 等等，使用 `set_template_option` 即可。
