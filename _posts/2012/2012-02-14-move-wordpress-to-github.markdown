---
layout: post
theme:
  name: twitter
title: 从wordpress博客迁移到github记录
category: perl
---

因为原先托管wordpress博客的阿里云主机被通管局要求备案，加上通管局早令夕改的浪费我来回的快递费，于是决定搬迁到国外，github page的免费托管就此进入我的视界。

## 第一步，申请github账号

这步大同小异，想个好名字就是了。

## 第二步，创建新项目

也就是注册完毕后在页面上看到的["New repository"](https://github.com/repositories/new)

在页面上填上项目名字。注意如果是要做博客的话，命名是有规范的，必须是yourusername.github.com这样子。

## 第三步，设置本地git环境

这步参见["help页面"]:(http://help.github.com/win-set-up-git/)

## 第四步，配置ruby和jekyll环境

一般来说，linux设备上肯定都已经有了ruby，不过版本比较低，所以升级ruby再使用：

```bash

    [root@localhost ~]# wget https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer
    [root@localhost ~]# bash rvm-installer
    [root@localhost ~]# rvm install 1.9.3
    [root@localhost ~]# rvm --default 1.9.3
    [root@localhost ~]# gem install jekyll

```

这样就可以在本地运行jekyll查看博客效果了。

```bash
    [root@localhost youusername.github.com]# jekyll --server
```

## 第五步，创建本地博客目录

这步，可以直接fork已有的github博客代码来用，比如：

```bash

    [root@localhost ~]# git clone https://github.com/plusjade/jekyll-bootstrap.git yourusername.github.com
    [root@localhost ~]# cd yourusername.github.com
    [root@localhost yourusername.github.com]# git remote set-url origin git@github.com:yourusername/yourusername.github.com.git
    [root@localhost yourusername.github.com]# git add .
    [root@localhost yourusername.github.com]# git commit -m 'first commit'
    [root@localhost yourusername.github.com]# git push origin master

```

## 第六步，修改必要信息

最重要的一步，创建目录下的CNAME信息，如果是fork的其他人的项目，那么修改CNAME的内容为自己的域名，比如blog.yourdomain.me。不然只能通过github的二级域名yourusername.github.com来访问了。
然后跟github无关的重要一步，上godaddy或者dnspod之类的地方，修改NS记录。注意这里，虽然上面文件叫CNAME，dns上却是要配置一个A记录，把A记录指向207.97.227.245即可。

## 第七步，添加评论功能

因为github提供的是一个静态页面托管，所以评论功能是需要用其他地方提供的。大家都用的是disqus的插件。所以上[disqus主页](http://disqus.com/) 去申请一个账号吧。然后按照提示，将提供的插件代码键入_includes/post.html中----不过一般来说，fork出来的都已经有了。

2012-03-16 补充：
最近也有其他的社会化第三方评论系统出现，可以使用微博、QQ来登录评论，免去上disqus注册之苦。大家可以上[友言](http://uyan.cc/getcode?index)看看。

2012-04-29 补充：
今天收到友言的提示邮件，上去看了一下，其实友言是支持[xml导入评论](http://uyan.cc/setting/backup)的。那么我们就可以把wp里的评论也一块导出来玩了：
```perl

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBI;
    use DBD::mysql;
    
    open my $fh, '>', 'comments.xml' or die $!;
    print $fh '<?xml version="1.0" encoding="utf-8"?>'; 
    print $fh '<uyan xmlns="http://uyan.cc" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';
    
    my $dbh = DBI->connect("DBI:mysql:database=blog;host=localhost;port=3306", "user", "passwd", {RaiseError => 1});
    $dbh->do('set names utf8');
    my $sth = $dbh->prepare('select p.post_title title, c.comment_author author, c.comment_author_url url, c.comment_date date, c
    .comment_content content from wp_comments c, wp_posts p where c.comment_approved='1' and c.comment_post_ID = p.ID');
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
        print $fh '<post><content>'.$ref->{'content'}.'</content>';
        print $fh '<page_title>'.$ref->{'title'}.'</page_title>';
        print $fh '<user_id>0</user_id>';
        print $fh '<comment_author>'.$ref->{'author'}.'</comment_author>';
        print $fh '<time>'.$ref->{'date'}.'</time>';
        print $fh '<from_type>wordpress</from_type>';
        print $fh '<page>'.$ref->{'url'}.'<page>';
        print $fh '<page_url>'.$ref->{'url'}.'</page_url>';
        print $fh '<domain>youdomain.com</domain></post>';
    };
    print $fh '</uyan>';

```

## 第八步，导出wordpress博客文章

jekyll提供了ruby脚本/usr/local/rvm/gems/ruby-1.9.3-p0/gems/jekyll-0.11.2/lib/jekyll/migrators/wordpress.rb来专门做这件事情，只需要运行如下命令即可：

```bash

    [root@localhost yourusername.github.com]# gem install sequel
    [root@localhost yourusername.github.com]# gem install mysql -- --with-mysql-config=/usr/bin/mysql_config
    [root@localhost yourusername.github.com]# ruby -rubygems -e 'require "jekyll/migrators/wordpress"; Jekyll::WordPress.process("database", "user", "pass")'

```

不过我这里运行有点问题，ruby又不太懂，再看完上面这个脚本的意思后，干脆放弃排错，直接用perl完成了如下这个脚本：

```perl

    #!env perl
    use warnings;
    use strict;
    use DBI;
    use DBD::mysql;
    
    my $dbh = DBI->connect("DBI:mysql:database=blog;host=localhost;port=3306", "user", "passwd", {RaiseError => 1});
    $dbh->do('set names utf8');
    my $sth = $dbh->prepare("select post_title, post_name, post_date, post_content FROM wp_posts WHERE post_status = 'publish' AND post_type = 'post' order by id desc ");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
        my $slug = $ref->{'post_name'};
        next unless $slug =~ m/^\w/;
        my $title = $ref->{'post_title'};
        my $date = substr($ref->{'post_date'}, 0, 10);
        my $content = $ref->{'post_content'};
        my $filename = $date . '-' . $slug . '.textile';
        my $header = "---\nlayout: post\ntitle: " . $title . "\ndate: " . $date . "\n---\n\n";
        open my $fh, '>', "$filename" or die $!;
        print $fh $header;
        print $fh "$content\n";
        $fh->close;
    }
    $sth->finish();
    $dbh->disconnect();

```

注意到中文url的不可读性，需要提前把wordpress的博客静态化url改成英文的。好在我一年前已经这么做了。
比较郁闷的一点是：wordpress的tag和category存放的表结构太恶心了，犹豫很久，最后放弃了导出博文对应category和tags的想法...

