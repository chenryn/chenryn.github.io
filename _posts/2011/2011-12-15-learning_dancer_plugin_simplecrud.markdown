---
layout: post
theme:
  name: twitter
title: Dancer::Plugin::SimpleCRUD模块学习
date: 2011-12-15
category: dancer
tags:
  - perl
  - MySQL
---

Dancer圣临历中介绍了一个新插件Dancer::Plugin::SimpleCRUD。可以很快的生成对数据库表的create/read/update/delete。大概阅读了一下代码。主要就是使用HTML::FromDatabase模块生成read的页面，用CGI::FormBuilder模块生成create/update/delete的页面，用Dancer::Plugin::Database::Handle模块操作数据库。因为是Simple，所以html代码都是固定的，不甚美观。但是思路可以学习，通过这两个模块，可以自己结合Dancer的template系统做CRUD了。
先来说HTML::FromDatabase模块，这个只涉及select，所以特别简单：
```perl
any ['get', 'post'] => '/add/:element' => sub {
    my $element = params->{'element'};
    if ( request->method eq 'GET' ) {
        my $sth = database->prepare("select * from $element");
        $sth->execute();
        my $table = HTML::Table::FromDatabase->new( -sth => $sth )->getTable;
        template 'info', { table => $table };
    };
...
};
```

这样就可以了，getTable方法的返回是一个字符串(内容就是table/tr/td代码)，直接传递给tmpl就行了~~
然后看CGI::FromBuilder模块：
```perl
any ['get', 'post'] => '/add/:element' => sub {
    my $element = params->{'element'};
    my $paramsobj = request->method eq 'POST' ? { params => { params() } } : undef;
    my @fields;
    if ( $element eq 'food' ) {
        @fields = qw/fid name shelf/;
    } elsif ( $element eq 'market' ) {
        @fields = qw/mid name location/;
    } elsif $element eq 'price' ) {
        @fields = qw/fid mid price time/;
    } else {
        return "Error element";
    };
    my $form = CGI::FormBuilder->new(
        params => $paramsobj,
        fields => \@fields,
    );

    my $sth = database->prepare("select * from $element order by fid desc");
    $sth->execute;
    my $default_hashref = $sth->fetchrow_hashref;
    my $action = $default_hashref ? 'update' : 'insert';
    if ( request->method eq 'POST' && $form->submitted && $form->validate ) {
        my $success = database->quick_update("$element", {name => params->{'name'}}, {shelf => params->{'shelf'} });
        redirect "/add/$element" if $success;
        return "update error";
    } else {
#        return $form->render(values => $default_hashref,
        my $hash = $form->prepare(values => $default_hashref,
                             title  => $element,
                             action => "/add/$element",
                             method => "post",
                            );
        template 'crud', { hash => $hash, };
    };
};
```

这里的关键，就是$paramsobj变量。否则无法区分GET和POST的。
和HTML::FromDatabase一样，有个render()直接返回内容是组装好的html代码的字符串；另外，CGI::FormBuilder模块还提供一个prepare()方法，返回的是hash——因为render()返回的html代码是完整的html/head/body...（事实上CGI::FormBuilder模块的构造器还提供指定js函数和css格式的参数）；所以如果要加进template里，可以把prepare()返回的hash传递给tmpl去操作！
然后还发现一个小问题，如果table里一条数据都没有，fields为undef，模块运行有问题的……
最后，_quick_update()是Dancer::Plugin::Database::Handle模块里提供的，这个模块里提供了一系列_quick_*()方法，用来快速操作数据库。
