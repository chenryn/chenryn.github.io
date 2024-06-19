---
layout: post
theme:
  name: twitter
title: nginx两个小测试(perl_set/image_filter)
date: 2011-05-30
category: nginx
tags:
  - perl
---

第一个测试，关于http_perl_module。之前写过一篇关于nginx忽略大小写的博文，今天被朋友问上门来，url是类似/Upload/Dir/2011/123_D.jpg的形式。如果单纯的lc($r->uri)，得到的url会变成/upload/dir/2011/123_d.jpg，目录是不存在的。所以要稍微改进一下。如下：
```perl    perl_set $url '
        sub {
            my $r = shift;
            return $1.lc($2) if ($r->uri =~ m/^(.+\/)([^\/]+)$/);
            return $r->uri;
        }
    ';```
这样就行了。

另一个测试，关于http_image_filter_module。配置语句很简单，就一行image_filter [size|resize|corp] wight height;就行了——如果图片太大，那还要加大image_filter_buffer，默认1M，大于这个大小的图片就不会缩略了。
比如配置如下：
```nginx
        location / {
            root   /var/www/html;
            index  index.html index.htm;
        }
        location ~* ^/small/w_(\d+)/h_(\d+)/(.*)$ {
            rewrite /small/w_(\d+)/h_(\d+)/(.*)$ /$3 break;
            image_filter resize $1 $2;
            root   /var/www/html;
            index  index.html index.htm;
        }```
这样通过/small/w_100/h_50/path/to/text.jpg，就能访问到/path/to/text.jpg的100*50大小的缩略图了。
如果只需要修改h或者w，其他的等比缩略，把另一项写成'-'即可。
其他参数介绍：test，返回是否真的是图片；corp，截取图片的一部分；size，以json格式返回图片的长宽数据。
