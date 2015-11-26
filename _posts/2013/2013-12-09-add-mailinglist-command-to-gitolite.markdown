---
layout: post
title: 为 gitolite 实现 mailinglist 命令行操控
category: perl
tags:
  - git
  - linux
  - ssh
---

gitolite 是一个很常用的 git 仓库管理软件，可以通过命令行方式便捷操作自己拥有权限的项目仓库。不过不是所有的操作都可以通过命令完成，很多还是需要通知 gitolite 管理员来统一修改配置然后生效。比如通过 hook 发邮件这件事情。邮件收件人地址肯定每个项目就不一样，这个还要让管理员逐一来改，就不太好。所以这里实现了一个 mailinglist 的命令行操作子命令。

使用说明
=============

1. 要求.gitolite.rc 中开启 GIT_CONFIG_KEYS 允许 hooks
2. 要求.gitolite.rc 中开启 ENABLE 允许 mailinglist
3. 在.gitolite/hooks/common/ 下软连接 git 默认的 post-receive-email 成 post-receive 文件

注意这里修改的 hooks 是针对整个 gitolite 的总 hooks 目录。而不是每个 repo 自己的 hooks，这个是单独有 repo-special-hooks 命令来管理的。

代码修改
============

代码上的修改主要就是两处：

* 新增文件 src/commands/mailinglist 如下；

```perl
    #!/usr/bin/perl
    use strict;
    use warnings;
    use Data::Dumper;
    use lib $ENV{GL_LIBDIR};
    use Gitolite::Rc;
    use Gitolite::Common;
    use Gitolite::Easy;
    use Gitolite::Conf::Load;
    
    our %one_repo;
    our %one_config;
    
    my $repo = $ARGV[0];
    my $addr = $ARGV[1];
    
    $ENV{GL_USER} or _die "GL_USER not set";
    
    my $generic_error = "repo does not exist, or you are not authorised";
    
    _die $generic_error if not owns($repo);
    
    if ( $addr ) {
        # write
        _chdir("$rc{GL_REPO_BASE}/$repo.git");
    
        if ( -f "gl-conf" ) {
            my $cc = "./gl-conf";
            _die "parse '$cc' failed: " . ( $! or $@ ) unless do $cc;
        }
    
        my $num;
        my $i;
        for ( @{ $one_config{$repo} } ) {
            $num = $_->[0];
            next unless $_->[1] eq 'hooks.mailinglist';
            $_->[2] = $addr and $i++ and last;
        }
        push @{$one_config{$repo}}, [ $num, 'hooks.mailinglist', $addr] unless $i;
    
        open( my $compiled_fh, ">", "gl-conf" ) or _die $!;
    
        my $dumped_data = '';
        $dumped_data = Data::Dumper->Dump( [ \%one_repo ], [qw(*one_repo)] );
        $dumped_data .= Data::Dumper->Dump( [ \%one_config ], [qw(*one_config)] );
    
        print $compiled_fh $dumped_data;
        close $compiled_fh;
    
    } else {
        # read
        my $val  = git_config($repo, 'hooks.mailinglist');
        print $val->{'hooks.mailinglist'};
    }
    
    1;
```

* 修改 src/lib/Gitolite/Rc.pm 如下：

    @@ -459,7 +459,7 @@ __DATA__
         UMASK                           =>  0077,
     
         # look for "git-config" in the documentation
    -    GIT_CONFIG_KEYS                 =>  '',
    +    GIT_CONFIG_KEYS                 =>  'hooks.*',
     
         # comment out if you don't need all the extra detail in the logfile
         LOG_EXTRA                       =>  1,
    @@ -520,6 +520,7 @@ __DATA__
                 'info',
                 'perms',
                 'writable',
    +            'mailinglist',

gitolite 本身相关的代码解析，和实现思路，我写成了这个 slide，欢迎观看：

<div><embed src='http://www.docin.com/DocinViewer-737880351-144.swf' width='100%' height='600' type=application/x-shockwave-flash ALLOWFULLSCREEN='true' ALLOWSCRIPTACCESS='always'></embed></div>
