---
layout: post
title: 通过 Rex 命令行参数向动态服务器组发起任务
category: devops
tags:
  - rex
  - sqlite
  - perl
---

Rex 默认的服务器组定义方式有三种，直接写在 `Rexfile` 文件中；每行一个写成 IP 列表保存成文件，然后通过 `lookup_file` 读取；把组名和 IP 写成 `.ini` 格式文件，通过 `groups_file "$name.ini"` 一次性获取。

如果服务器信息存在数据库里，那么可以通过 `Rex::Commands::DB` 来快速读取数据库信息，构建服务器组。不过，如果我们是想从数据库中根据查询条件，动态获取服务器列表完成指定任务的话，就没法提前定义好 `group` 了。这个时候，怎么办呢？

我们可以利用 `task` 可以接受命令行参数这个特点，完成这个功能：

```perl
use Rex::Commands::DB {
    dsn      => "dbi:SQLite:dbname=/etc/puppet/webui/node.db",
    user     => "",
    password => "",
};

task "sqlite", sub {
    my $param = shift;
    my $role  = $param->{role};
    my $class = $param->{class};
    my $todo  = $param->{todo};
    grep { run_task $todo, on => $_->{ip} } db select => {
        fields => "ip",
        from   => "node_info",
        where  => "role like '$role\%' and classes like '\%${class}\%'",
    };
};

task 'hello', sub {
    say run "w";
};
```

然后这样运行命令即可：

```bash
rex sqlite --role=cdn --class=nginx --todo=hello
```
