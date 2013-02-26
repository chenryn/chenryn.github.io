---
layout: post
title: 给 Sysadmin Advent 快速搭建本地浏览网站
category: perl
---
一年一度的 advent 集合中，除了 perl 的部分，还有 sysadmin 的也很吸引我等运维的眼球。不过 sysadmin 的一直是发表在blogspot 上，光荣的被 GFW 认证了。虽然说翻墙应该是这年头越来越普及的技能，但是能提供免墙的办法，想来那真真是极好的。

这里提供一个私以为很不错的办法。因为我很开心的发现 sysadvent 有托管在 github 上。

{% highlight bash %}
    sudo apt-get install git
    git clone git://github.com/jordansissel/sysadvent.git
    sudo wget http://xrl.us/cpanm --no-check-certificate -O /sbin/cpanm
    sudo chmod +x /sbin/cpanm
    cpanm Plack DocLife
{% endhighlight %}

好了，准备工作完毕。然后在 sysadvent 目录下创建 app.psgi 文件如下：

{% highlight perl %}
    use Plack::Builder;
    use Plack::App::Directory;
    use DocLife::Markdown;
    my $html_app = DocLife::Markdown->new(
        root => '.',
        base_url => '/html/',
        suffix => '.html',
    );
    my $md_app = DocLife::Markdown->new(
        root => '.',
        suffix => '.md',
        base_url => '/md/'
    );
    my $dir_app = Plack::App::Directory->new({
        root => '.',
    });
    builder {
        mount '/md' => $md_app;
        mount '/html' => $html_app;
        mount '/' => builder {
            enable "Plack::Middleware::SimpleContentFilter",
            filter => sub {
                s#(/\d{4}/\d{2}/\S+\.md)#/md\1#;
                s#(/\d{4}/\d{2}/\S+\.html)#/html\1#;
            };
            $dir_app
        };
    };
{% endhighlight %}

`Plack::App::Directory` 模块是 `Plack` 自带的一个静态目录自动索引发布模块。不过他会把 markdown 当成 "text/plain" 发布，不好看。所以这里引入了另一个 `DocLife` 模块。他可以自动把 markdown 和 pod 格式的文档美化转换成 html 格式。本来 `DocLife` 本身也提供目录索引功能，不过他的问题是他不考虑 MIME 问题，会把 png 等图片也以 "text/plain" 发布。所以我们用 `Plack::App::URLMap` 把两个模块挂在到一起，然后用 `Plack::Middleware::SimpleContentFilter` 过滤内容，替换原本的目录链接成针对性的目录。

大功告成！运行命令开始享受世界级运维们的分享吧：

{% highlight bash %}
    plackup &
    open localhost:5000
{% endhighlight %}

注：另外有个 `Plack::App::Directory::Markdown` 模块，不过他写死了只处理 md，连 html 都被 `next`。比较好玩的是这个模块自己把 bootstrap.css|js 给放到 `__DATA__` 块里一起分发了，页面倒是更好看一点。
