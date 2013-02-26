---
layout: post
title: 写个同步分发系统(二)
date: 2011-09-26
category: dancer
tags:
  - perl
---

接上篇，加上分发过程查看的页面。这应该是一个很典型的翻页处理。
首先创建一个数据库表如下：
{% highlight mysql %}create table websync_peer (
    id int not null auto_increment primary key,
    begin_time timestamp not null default 0,
    end_time timestamp on update current_timestamp,
    url varchar(128) not null,
    customer varchar(20) not null,
    md5_hex char(32) default null
) engine=innodb;{% endhighlight %}
然后把之前的peer_query()函数修改如下：
{% highlight perl %}sub peer_query {
    my $url = shift;
    #这里的database和session都需要其他plugin的配合，见之前博客，不贴重复代码了
    my $sth = database->prepare('insert into websync_peer (begin_time, url, customer) value (now(), ?, ?)');
    $sth->execute($url, session->{login});
};{% endhighlight %}
然后把gearman::client的功能改到mysql的UDFs内完成，做法见<a href="http://www.php-oa.com/2010/09/20/perl-gearman-server-mysql-udfs.html" title="http://www.php-oa.com/2010/09/20/perl-gearman-server-mysql-udfs.html"></a>。
然后写翻页函数了~
{% highlight perl %}get '/check' => sub {
    my $from = params->{page} || 1;
    my $user = session->{login};
    my @urls;
    my $count_sql = 'select count(id) count from websync_peer where customer = ?';
    my $count_sth = database->prepare($sql);
    $count_sth->execute( $user );
    my $count = $count_sth->fetchrow_hashref->{count};
    my $total_pages = int( $count / 20 + 1 );
    return 'No url has been posted to purge.' unless $count;
    return 'Selected page number out of range.' if $from > $total_pages;
    my $url_sql = 'select id,url,begin_time from websync_peer where customer = ? order by id desc limit ?, 20';
    my $url_sth = database->prepare($sql);
    $url_sth->execute( $user, ($from - 1) * 20 );
    while ( my $ref = $sth->fetchrow_hashref ) {
        push @urls, $ref;
    };
    template 'check', { 'urls' => \@urls, 
                        'prev' => $from > 1 ? $from - 1 : 1,
                        'next' => $from < $total_pages ? $from + 1 : $total_pages, 
                        'last' => $total_pages, 
                      };
};{% endhighlight %}
对应的check.tt如下：
{% highlight html %}<html><head>
<style type="text/css">
#main {text-align:center;width:500px;margin-right:auto;margin-left:auto;padding:0px;}
#url {width:776px;border:1px;}
#page_link ul {list-style:none;}
#page_link li {float:left;width:100px;margin-left:3px;line-height:30px;}
</style>
</head><body>
<div id="main">
<div id="url">
<table>
<tr><th>ID</th><th>URL</th><th>TIME</th><th>MORE</th></tr>
<% FOREACH ref IN urls %>
<tr>
<td><% ref.id %></td>
<td><% ref.begin_time %></td>
<td><% ref.url %></td>
<td><a href="/checkstatus?id=<% ref.id %>">more</a></td>
</tr>
<% END %>
</table>
</div>
<div id="page_link"><ul>
<li><a href="/check?page=1">1</a></li>
<li><a href="/check?page=<% prev %>"><% prev %></a></li>
<li><a href="/check?page=<% next %>"><% next %></a></li>
<li><a href="/check?page=<% last %>"><% last %></a></li>
</ul></div>
</div>
</body></html>{% endhighlight %}
额，傻乎乎的css，好难看，好难写啊……
下一步继续修改mysql表结构，然后完成页面里提供的/checkstatus功能。
