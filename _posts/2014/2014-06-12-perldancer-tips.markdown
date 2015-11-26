---
layout: post
title: PerlDancer 框架笔记
category: perl
tags:
  - dancer
---

Dancer 是 Perl 的 web 开发框架，在 metacpan 上有 100 多个 like。其语法结构都起源自 Ruby 的 sinatra 框架，sinatra 曾经在自己官网上悬挂“perldancer is good”标语以示对 perldancer 的支持。Dancer 官网见： <http://perldancer.org/> 本文系本人在部门 Wiki 上稍微写的几行介绍性质的笔记。

## 简单示例

Dancer 作为微框架，可以直接单文件快速运行简单的 web 功能。示例如下：

```perl
    use Dancer;
    get '/' => sub {
        return "hello world";
    };
    dance;
```

然后直接通过 `perl test.pl` 命令既可以在 localhost:3000 运行起来一个 hello world 页面了。

## 目录结构

完整的 Dancer 应用，可以通过 `dancer -a MyApp` 命令创建，目录结构如下：

    MyApp/
    ├── bin
    │   └── app.pl                    # 程序运行入口，可以直接通过./app.pl运行，也可以通过plackup -s Starman app.pl来切换其他高性能服务器
    ├── config.yml                     # 主配置文件
    ├── environments
    │   ├── development.yml
    │   └── production.yml
    ├── lib
    │   └── MyApp.pm                  # Perl代码入口，route、controller、ORM 等都在 lib 下
    ├── Makefile.PL
    ├── MANIFEST
    ├── MANIFEST.SKIP
    ├── public                         # public/ 下的文件会直接作为静态文件发布，相当于 DocumentRoot
    │   ├── 404.html
    │   ├── 500.html
    │   ├── css
    │   │   ├── error.css
    │   │   └── style.css
    │   ├── dispatch.cgi
    │   ├── dispatch.fcgi
    │   ├── favicon.ico
    │   ├── images
    │   │   ├── perldancer-bg.jpg
    │   │   └── perldancer.jpg
    │   └── javascripts
    │       └── jquery.js
    ├── t
    │   ├── 001_base.t
    │   └── 002_index_route.t
    └── views                           # views/ 下的文件是页面模板，在 lib 里通过 template('index') 方式调用
        ├── index.tt
        └── layouts
            └── main.tt                 # layouts 是页面模板的底层模板，主底层模板可以在 config.yml 里指定

## 常用插件

目前用 Dancer 写的 CdnManage 平台，用到的插件包括：

* Dancer::Template::Xslate

采用 Text::Xslate 作为模板引擎。xslate 引擎是用 XS 写的类 Perl6 语法模板引擎，性能很好。语法示例如下：

    <: $object.accessor :>
    <: $str :>
    <: $array.0 :>
    <: $hash.key :>
    : for $arrayref -> $item {
        index: <: $~item :> value: <: $item :>
    : }
    : if ( $var == nil ) {
    : } else if ( $val == "text" ) {
    : } else {
    :     while $dbh.fetch() -> $item {
    :     }
    : }

注意，CdnManage 中，因为是从 TT2 模板迁移到 xslate 里的，所以单独配置了 config.yml，没有用 : 号而是沿用了 % 号。

* Dancer::Session::YAML

采用 YAML 存储 session，这个作为内部应用足够了，升级的话应该用 mysql、mongo、elasticsearch之类的存储，都有现成插件。

* Plack::Middleware::Deflater
* Plack::Middleware::ETag

上面两个作为给 public/ 下文件加缓存和压缩的优化。在 config.yml 里添加如下配置即可使用：

```yaml
plack_middlewares:
  -
    - Plack::Middleware::Deflater
    - Plack::Middleware::ETag
```

* Dancer::Plugin::Auth::Extensible

给 route 加认证功能，有 require_role 和 require_user 两种形式，示例如下：

```perl
    get '/admin' => require_user 'admin' => sub {};
    post '/purge' => require_role qr/^purge_\w+/ => sub {};
```

* Dancer::Plugin::Email

发邮件

* Dancer::Plugin::GearmanXS

将需要较长时间运行完的任务通过 gearman 分发到其他后台任务脚本上去完成。

* Dancer::Plugin::Datebase

数据库插件，可以直接按照 DBI 操作，也提供了简单的 quick_select/insert 等指令。示例如下：

```perl
    get '/users/:id' => sub {
        template 'display_user', {
            person => database->quick_select('users', { id => params->{id} }),
        };
    };
```

如果在 config.yml 定义了多个库，则通过 `database('name')` 的方式来调用。

```yaml
  Database:
    connections:
      puppet:
        driver: "SQLite"
        database: "/etc/puppet/webui/node_info.db"
      cdnmanage:
        driver: "mysql"
        database: "cdnmanage"
        host: "127.0.0.1"
        port: 3306
        username: "user"
        password: "pass"
        connection_check_threshold: 10
        on_connect_do: ["SET NAMES 'utf8'", "SET CHARACTER SET 'utf8'" ]
```

更完善的 ORM 使用，见 Dancer::Plugin::DBIC 插件，他使用的是 DBIx::Class 框架做 ORM，示例如下：

```perl
    get '/users/:user_id' => sub {
        my $user = schema('default')->resultset('User')->find(param 'user_id');
        # 如果只有一个默认的schema在config.yml里那么上面这行可以简写成下行
        $user = rset('User')->find(param 'user_id');
        template user_profile => {
            user => $user
        };
    };
```

* Dancer::Plugin::ElasticSearch

elasticsearch 插件，类似 Dancer::Plugin::Database；所以同理，也有更偏 ORM 一点的 Dancer::Plugin::ElasticModel 插件。

* Dancer::Plugin::Deferred

页面消息提示插件。使用示例：

```perl
    hook before => sub {
        if (    request->uri =~ m#^/puppetdb/#
            and request->uri !~ m#^/puppetdb/api/#
            and !user_has_role('SOM') )
        {
            deferred error => 'no permission';
            redirect '/';
        }
    };
```

然后在底层模板layouts/main.tt 中：

    %% if $deferred.error {
      <div class="alert alert-success"> [% $deferred.error %] </div>
    %% }

* Dancer::Plugin::Ajax

扩展默认的 get/post/delete/put 指令，提供 ajax 指令。

* Dancer::Plugin::SimpleCRUD

提供简便的数据库 CRUD 操作表单。目前 Puppet 的 SQLite 操作实例如下：

```perl
  simple_crud(
    db_connection_name => 'puppet',
    db_table           => 'node_info',
    key_column         => 'id',
    prefix             => 'node_info',
    record_title       => 'Puppet Node',
    deleteable         => 1,
    paginate           => 50,
    validation         => {
        classes     => '/^(\w,?)+$/',
        role        => '/^\w+$/',
        environment => '/^\w+$/',
    },
    message => {
        classes => 'enter like "puppetd,repos"',
        role    => 'an english word only',
    },
    display_columns => [qw(node_fqdn environment role)],
    custom_columns  => {
        include_classes => {
            raw_column => 'classes',
            transform  => sub {
                my @classes = split( /,/, shift );
                my $self    = shift;
                my $role    = $self->{'role'};
                my $env     = $self->{'environment'};
                my @lines;
                push @lines, "<a href='/puppetdb/$env/$_/$role/view'>$_</a>"
                  for @classes;
                return join( " / ", @lines );
            },
        },
    },
  );
```

