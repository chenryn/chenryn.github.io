---
layout: post
title: CloudForecast学习笔记(三)
date: 2011-08-18
category: perl
---

第三篇，看web部分。主程序cloudforecast_web里主要就是调用CloudForecast::Web的run()函数，接下来去看CloudForecast::Web。
照例还是加载配置，然后这里主要多了两个accessor：allowfrom和front_proxy。用来定制acl和代理的。从下文可以看到，分别是采用了Plack::Middleware::Access和Plack::Middleware::ReverseProxy两个模块进行控制。
然后是主要部分，通过Plack::Builder建立$app：
1、初始化:"my $app = $self->psgi;"，这里是调用父层"use Shirahata -base;"的psgi()函数完成的。稍后再看这个。
2、包装:取出前面说的allowfrom和front_proxy部分后，代码如下：
{% highlight perl %}
    $app = builder {
        enable 'Plack::Middleware::Lint';
        enable 'Plack::Middleware::StackTrace';
        enable 'Plack::Middleware::Static',
            path => qr{^/(favicon\.ico$|static/)},
            root =>Path::Class::dir($self->root_dir, 'htdocs')->stringify;
        $app;
    };{% endhighlight %}
真实加载顺序是倒序的，先加载Static.pm，用来服务静态文件，意即url路径为^/static/.*的，实际documentroot为./htdocs/；然后加载StackTrace.pm，用于开发调试的时候，向标准输出输出错误跟踪信息；最后是Lint.pm，用于检查请求/响应的格式是否正确。
然后是加载运行，使用Plack::Loader运行上面build出来的$app。方法如下：
{% highlight perl %}
    my $loader = Plack::Loader->load(
        'Starlet',
        port => $self->port || 5000,
        host => $self->host || 0,
        max_workers => 2,
    );
    $loader->run($app);{% endhighlight %}
主要是两个参数，第一个是用来运行plack的服务器模块名称，常见的有starman/twiggy/corona/perlbal等等，这里写的这个Starlet，是基于HTTP::Server::PSGI模块添加预派生(prefork)/热部署(Server::Starter)/优雅重启等功能的一个服务器模块，原来叫的名字是"Plack::Server::Standalone::Prefork::Server::Starter"(简称PSSPSS)……

然后去看前面说到的Shirahata.pm里的psgi()函数。
这个Shirahata似乎是作者自己完成的一个框架？反正我在cpan上没看到。psgi()里调用build_app()完成主要功能，其中使用了Router::Simple完成route功能，Data::Section::Simple(提取文件中_DATA_下的内容)和HTML::FillInForm::Lite()、Text::Xslate完成template功能，Plack::Request和Plack::Response完成请求响应功能，最终返回一个"$psgi_res;"。
一堆模块没一个看过的……不细究了……
