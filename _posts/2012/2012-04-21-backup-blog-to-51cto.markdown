---
layout: post
title: 51CTO博客自动发布脚本
date: 2012-04-21
category: perl
---

{% highlight perl %}
#!/bin/env perl
use warnings;
use strict;
use File::Util;
use YAML::Syck;
use Perl6::Say;
use XMLRPC::Lite;
use Data::Dumper;

my $f = File::Util->new;
my @blogs = grep {/\.markdown$/} $f->list_dir('../_posts', '--recurse');
foreach (@blogs) {
    my $yaml = LoadFile($_);
    my $title = $yaml->{'title'};
    my $text = $f->load_file("$_");
    upload($title, $text);
};

sub upload {
    my ($title, $text) = @_;
    my $username = 'username';
    my $password = 'password';
    my $blogid   = '123456';
    my $proxyurl = 'http://blogname.blog.51cto.com/xmlrpc.php';
    my $res = XMLRPC::Lite->proxy($proxyurl)->call('metaWeblog.newPost', $blogid, $username, $password, { title => "$title", description => "$text", categories => ['【创作类型:原创】','IT管理', ]}, 1)->result;
    say "newPost id -- " . $res if $res;
};
{% endhighlight %}

目前还有几个问题：

1. 虽然写了创作类型是原创，但是发布后还是转载；
2. categories的数组生成的xml格式是<array><data><value><base64>，但通过wireshark抓包windows live writer看到能被api接收的格式应该是<array><data><value><string>。在XMLRPC::Lite的代码中，有as_base64/as_string等好几个方法，但是找到从哪里定义使用，目前简单的采用注释掉了XMLRPC::Lite::Serializer::new()方法里的base64键值对，但是理论上应该不用修改源码的；
3. 最后一个最关键的问题，不管我在服务器上是用utf8还是gb2312，上传后都是乱码。估计第一个问题其实也是由此产生的。

