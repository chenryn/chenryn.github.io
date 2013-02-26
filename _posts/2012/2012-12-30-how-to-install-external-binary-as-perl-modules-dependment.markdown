---
layout: post
title: perl 模块打包加入外部依赖程序
category: perl
---

Perl 社区并不是所有的东西都发布在 CPAN 上。甚至专门有一个 `Module::ThirdParty` 模块记录这些非 CPAN 的 perl 项目列表。其中最有名的应该就属写博客的 `Movable Type` 和做监控的 `SmokePing` 了。

但是如果个人图方便又想把 smokeping 打包方便部署使用的时候，就会发现一点小问题：打包成rpm，很多 perl 的依赖模块不一定在系统 repo 里存在；打包成 perl 的模块，smokeping 最常用的几个 probe 比如 fping、curl 什么的，又是非 perl 程序，cpanm 没法解决这个 `requires_external_bin` ，最多只能报错退出。

其实这里可以采取一些别的办法，虽然笨一些，但是解决问题。

首先还是让我们创建一个示例模块：

{% highlight bash %}
    cpanm Module::Starter Module::Build
    module-starter --module Alien::FPing --author="Jeff Rao" --email="myname@gmail.com" --mb
{% endhighlight %}

然后就会在本目录下创建一个 Alien-FPing 目录，自带好了 `Build.PL` 等模块文件。这里使用了 `Alien::` 的名字空间，是一个潜规则，有些项目依赖 C 源码的库和头文件，就用 perl 包一层来安装，都放在这个空间下，比如 `Alien::V8`, `Alien::Gearmand`, `Alien::IE7` 等等。

现在让我们下载 fping 的源码放到模块里：

{% highlight bash %}
    mkdir Alien-FPing/src
    wget http://www.fping.org/dist/fping-3.4.tar.gz -O Alien-FPing/src/fping-3.4.tar.gz
{% endhighlight %}

接下来应该就是编写 `Build.PL` 了。不过为了尽量让 `Build.PL` 看起来简洁而且一眼看出目的。我们最好把编译操作单独定义一个模块来使用：

{% highlight perl %}
    package Alien::FPing::Build;
    use base qw(Module::Build);
    use File::Spec;
    use Archive::Tar;
    my $RootDir = File::Spec->rel2abs(".");
    my $SrcDir = File::Spec->catdir($RootDir, "src");
    my $FPingVersion = '3.4';
    my $FPingName = "fping-${FPingVersion}";
    my $FPingSrc = "${FPingName}.tar.gz";
    sub ACTION_build {
        my $self = shift;
        chdir($SrcDir);
        if (  !-x "/usr/sbin/fping" and !-d $FPingName ) {
            my $tar = Archive::Tar->new();
            $tar->read($FPingSrc);
            $tar->extract();
            chdir($FPingName);
            system('./configure', '--prefix=/usr/', '--enable-ipv6');
            system('make');
            system('make install');
        }
        $self->SUPER::ACTION_build();
    };
    1;
{% endhighlight %}

几乎就是调用 shell 而已，唯一需要讲一下的就是这个 `ACTION_build`。这是 `Module::Build` 定义好的提供给 `subclass` 用的方法，事实上 `./Build help` 看得到的所有 action 都有类似的方法可以用。

然后稍微修改一下 Build.PL 如下：

{% highlight perl %}
    use 5.006;
    use strict;
    use warnings FATAL => 'all';
    use lib 'inc';
    use Alien::FPing::Build;
    my $builder = Alien::FPing::Build->new(
        module_name         => 'Alien::FPing',
        license             => 'perl',
        dist_author         => q{Jeff Rao <myname@gmail.com>},
        dist_version_from   => 'lib/Alien/FPing.pm',
        release_status      => 'stable',
        configure_requires => {
            'Module::Build' => 0,
        },
        build_requires => {
            'Test::More' => 0,
        },
        requires => {
            #'ABC'              => 1.6,
            #'Foo::Bar::Module' => 5.0401,
        },
        add_to_cleanup     => [ 'Alien-FPing-*' ],
        create_makefile_pl => 'traditional',
    );
    $builder->create_build_script();
{% endhighlight %}

把 `Module::Build` 替换成 `Alien::FPing::Build` 而已，其他都不用动。

然后试一下吧：
{% highlight bash %}
    cd Alien-FPing
    perl Build.PL
    ./Build
{% endhighlight %}

看到编译输出，并且成功安装有 `/usr/sbin/fping` 了吧。现在可以打包了。注意默认生成的 ignore.txt 里，是排除掉了 inc 目录的，需要去除掉，然后修改 `MANIFEST` 文件加入 inc 和 src 里的文件，然后再打包出来的 perl 模块就可以直接用了。

{% highlight bash %}
    sed -i '/inc/d' ignore.txt
    echo 'inc/Alien/FPing/Build.pm' >> MANIFEST
    echo 'src/fping-3.4.tar.gz' >> MANIFEST
    ./Build dist
{% endhighlight %}
