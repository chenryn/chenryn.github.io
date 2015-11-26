---
layout: post
title: 写个同步分发系统(三)
date: 2011-09-29
category: dancer
tags:
  - perl
---

上篇写的页面上，留下一个超链接，查看每条任务的具体情况。现在完成这部分。
首先修改数据库结构，上篇已经建了websync.websync_peer表，现在继续：
```mysql
create table websync_customer (
    uid int not null auto_increment primary key,
    user varchar(20) not null,
    passwd char(32) not null,
    custom_info varchar(128),
    node varchar(128) not null
) engine=innodb;

create table remote_node (
    nid int not null auto_increment primary key,
    node_name varchar(16) not null,
    node_ip int(16) not null
) engine=innodb;

create table task_msg (
    id int not null auto_increment primary key,
    task_id int not null,
    node_id int not null,
    node_md5 char(32) default null,
    key (task_id),
    key (node_id),
    constraint task_f foreign key task_id references websync_peer (id) on delete cascade on update cascade,
    constraint node_f foreign key node_id references remote_node (nid) on delete cascade on update cascade,
) engine=innodb;```
主要内容，一是每个用户使用多少节点；二是各节点下载完url后反馈的md5值。
然后新增dancer动作如下:
```perlget '/checkstatus' => sub {
    my $task_id = params->{'id'};
    my $user = session->{'login'};
    my @status;

    my $task_sth = database->prepare('select md5_hex from websync_customer where id = ?');
    $task_sth->execute( $task_id );
    my $peer_md5 = $task_sth->fetchrow_hashref->{'md5_hex'};

    my $node_sth = database->prepare('select node from websync_customer where user = ?');
    $node_sth->execute( $user );
    my $nodes = $node_sth->fetchrow_hashref->{'node'};

    my $check_sql = 'selct remote_node.node_name node, task_msg.node_md5 md5 from task_msg join remote_node on (task_msg.node_id = remote_node.nid) where task_msg.task_id = ? and task_msg.node_id in ( ? )';
    my $check_sth = database->prepare( $check_sql );
    $check_sth->execute( $task_id, $nodes );
    while ( my $ref = $check_sth->fetchrow_hashref ) {
        my $node_name = $ref->{'node'};
        my $node_result;
        if ( ! defined $peer_md5 ) {
            $node_result = 'Peer synchronizing';
        } elsif ( ! defined $ref->{'md5'} ) {
            $node_result = 'Remote distributing';
        } elsif ( $ref->{'md5'} == $peer_md5 ) {
            $node_result = 'Distribute Over';
        } else {
            $node_result = 'Distribute Not Match';
        };
        push @status, { name => $node_name, result => $node_result, };
    };
    template 'checkstatus', { 'status' => \@status, };
};
```
对应的TT模板如下：
```html<html>
<head></head>
<body><table>
<tr><th>TASK</th><td><% task %></td></tr>
<tr><th>NODE</th><th>STATUS</th></tr>
<% FOREACH node IN status %>
<tr><td><% node.name %></td>
<td><% node.result %></td></tr>
<% END %>
</table></body>
</html>```
然后需要给admin加一个管理页面，勾选恰当的节点分配给客户。动作配置如下：
```perlany ['get', 'post'] => '/nodeadd' => sub {
    if ( request->method() eq 'GET' ) {
        my $node_sth = database->prepare('select node_name,nid from remote_node order by nid');
        $node_sth->execute();
        my @nodes;
        while ( my $ref = $node_sth->fetchrow_hashref ){
            push @nodes, { name => $ref->{'node_name'}, id => $ref->{'nid'}, };
        };

        my $user_sth = database->prepare('select user from websync_customer');
        $user_sth->execute();
        my @users;
        while (my $ref = $user_sth->fetchrow_hashref ) {
            push @users, $ref->{'user'};
        };

        template 'nodeadd', { 'users' => \@users,
                              'nodes' => \@nodes,
                            };
    } else {
        my $user = params->{'user'};
        my $nodes = params->{'nodes'};
        my $add_sth = database->prepare('update remote_node set nodes = ? where user = ?');
        $add_sth->execute( $nodes, $user );
    };
};```
对应的TT模板如下：
```html<html>
<head>
<script type="text/javascript">
function post_node() {
    var nodes = '';
    var user = '';
    $("form > [type=checkbox]").each(function(){
        if($(this)[0].checked) {
            nodes += $(this).val()+',';
        }
    });
    $("select > option").each(function(){
        if($(this).attr('selected')==true) {
            user = $(this).val();
        }
    });
    $.post('/nodeadd?nodes='+nodes+'&user='+user);
}
</head><body>
<form method="post" action="post_node()">
<% FOREACH node IN nodes %>
<input type="checkbox" name="node" value="<% node.id %>" /><% node.name %>
<% END %>
<HR />
<select name="customer">
<% FOREACH user IN users %>
<option value="<% user %>"><% user %></option>
<% END %>
<input type="submit" value="submit">
</form>
</body>
</html>```
从度娘那抄了个jquery例子来用……
