---
layout: post
title: 用 Mojo 命令行抓取数据完成自动更新 rpm 构建
category: perl
tags:
  - mojolicious
  - rpm
---

我一直很喜欢 `Dancer` 里的 keyword 方式，所以很少使用 `Mojolicious` 框架来写网站，不过 `Mojo::UserAgent` 和 `Mojo::DOM` 在一起作为爬虫工具使用，真是太方便了。这两天需要自己打包 `tengine` ，考虑自动化因素，需要从 `tengine` 和 其他第三方模块的 `github` 托管网页上定期查询其更新，都是一行代码就搞定了。整个 `Build.PL` 如下：

```perl
#!/usr/bin/env perl
use Modern::Perl;
use IPC::Run qw(run);
use File::Slurp;
use POSIX qw(strftime);
use Template;
use ojo;

my @ModuleList = qw(
    renren/ngx_http_accounting_module
    agentzh/echo-nginx-module
    agentzh/chunkin-nginx-module
    simpl/ngx_devel_kit
    calio/form-input-nginx-module
    chaoslawful/lua-nginx-module
    renren/ngx_http_consistent_hash
);

my $TengineMD5 = (split(/ /, g("http://tengine.taobao.org/download_cn.html")->dom->at(".one_col li span")->text))[-1];

write_file("md5.txt", "firstimetorun") unless -f "md5.txt";
my $TengineOldMD5 = read_file( "md5.txt" );

say $TengineOldMD5;
say $TengineMD5;

if ( $TengineMD5 ne $TengineOldMD5 ) {
    gettarball(\@ModuleList);
    write_file("md5.txt", $TengineMD5);
}

sub gettarball {
    my $ModuleList = shift;

    my $TengineUrl = g("http://tengine.taobao.org/download_cn.html")->dom->at(".one_col li a")->{href};
    my $TengineVersion = $1 if $TengineUrl =~ m!download/tengine-(.*).tar.gz!;
    my $TengineRelease = strftime("%Y%m%d%H%M",localtime);

    run('wget', "http://tengine.taobao.org/${TengineUrl}", '-O', "SOURCES/tengine-${TengineVersion}.tar.gz");

    my @ModuleFile;
    my $i = 10;
    for my $Module ( @{ $ModuleList } ) {;
        my $GitUrl = "https://github.com/${Module}";
        say $GitUrl;
        my $GitCommit = substr(g("${GitUrl}")->dom->at(".sha")->text, 0, 7);
        ( my $StoreName = $Module ) =~ s!/!-!;
        my $StoreFile = "${StoreName}-${GitCommit}.tar.gz";
        push @ModuleFile, [ "Source${i}" => "${StoreName}-${GitCommit}" ];

        run('wget', "${GitUrl}/tarball/master", '-O', "SOURCES/$StoreFile");

        $i++;
    }

    unlink('SPECS/tengine.spec');
    my $template = Template->new;
    $template->process("tengine.spec.tt", {
        TengineVersion => $TengineVersion,
        TengineRelease => $TengineRelease,
        TengineAddons  => \@ModuleFile,
    }, "SPECS/tengine.spec");

    buildrpm($TengineVersion, $TengineRelease);
}

sub buildrpm {
    my ( $TengineVersion, $TengineRelease ) = @_;
    my ( $out, $err );
    run ['rpmbuild', '-bb', 'SPECS/tengine.spec'], undef, \$out, $err;
    mail2author($err);
}

sub mail2author {
    my $output = shift;
    my $body = $output ? "Build Error: $output" : "Build OK";
    p("http://email.notify.d.xiaonei.com/eml/tengine-build/chenlin.rao" => { DNT => 1 } => $body);
}
```

直接 `g` 就是 GET 方法， `p` 就是 POST 方法。然后 `->dom->at()` 后采用类似 `jQuery` 的写法就可以直接定位，然后还可以用 `->text` 来获取内容，或者 `->{attr}` 来获取属性值。

顺带，今天刚知道原来 `Template` 模块也有 `filter` 可用。`tengine.spec.tt` 中就用了一个大写过滤：

```bash
Summary:    a HTTP and reverse proxy server
Name:       tengine
Version:    [% TengineVersion %]
Release:    [% TengineRelease %]

Source0:    %{name}-%{version}.tar.gz
Source1:    init.nginx
Source2:    logrotate.nginx
Source3:    nginx-renren-conf.tar.gz
[% FOREACH Module IN TengineAddons -%]
[% Module.0 %]:    [% Module.1 %].tar.gz
[% END %]

Group:      System Environment/Daemons
License:    BSD

BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}

Requires:      pcre,zlib,lua
BuildRequires: pcre-devel,zlib-devel,lua-devel
Requires(post):    chkconfig
Conflicts:     nginx

%description
Nginx with modules: 1) ngx_http_consistent_hash; 2) ngx_http_accounting_module; 3) agentzh-chunkin-nginx-module. 

%prep
#%setup -q 
%setup -n tengine-%{version}
tar zxvf %{SOURCE3}
[% FOREACH Module IN TengineAddons -%]
tar zxvf %{[% Module.0 FILTER upper %]}
[% END %]

...;
```
