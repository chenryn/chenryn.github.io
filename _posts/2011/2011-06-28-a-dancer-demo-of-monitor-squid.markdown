---
layout: post
theme:
  name: twitter
title: squid监控+dancer小试验
date: 2011-06-28
category: dancer
tags:
  - squid
  - perl
---

squid监控之前有一篇关于snmp的内容，不过这次是真要用上了，所以细细挑出来几个做监控。碰巧凯哥更新了一把modern perl的东西，我亦步亦趋，也试试dancer。不过花了两天时间，DBIx::Class::Schema还是没搞出来，最终还是简单的用DBI跳过了……
用的database就是之前nmap试验时生成的数据，有application/channel/intranet等column。
首先安装：
```perlcpanm Dancer DBI DBD:mysql Template Dancer::Session::YAML
dancer -a cachemoni
```
然后修改cachemoni/lib/cachemoni.pm如下：
```perl
package cachemoni;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Net::SNMP;
use Digest::MD5 qw(md5_hex);
our $VERSION = '0.1';

get '/monitor' => sub {
    my $app = params->{app} || 'squid';
    return 'Only support squid now' unless $app eq 'squid';
    my $checkstat = _snmp_check($app);
    template 'monitor', { status => $checkstat,
                          name   => ['IP地址','流量命中率','请求数命中率','回源请求响应毫秒','当前客户端数','剩余文件描述符数','已缓存文件数','平均每秒请求数'],
                        };
};

any['get', 'post'] => '/login' => sub {
    my $err;
    if ( request->method() eq 'POST' ) {
        my $name = params->{username};
        my $passwd = params->{password};
        my $sth = database->prepare(
            'select audit,passwd from ops_user where name = ?'
        );
        $sth->execute($name);
        my $ref = $sth->fetchrow_arrayref;
        if (!defined $ref) {
            redirect '/register';
        } elsif ( $ref->[0] ne 'yes' ) {
            $err = '你的帐户还没通过审核';
        } elsif ( md5_hex("$passwd") ne "$ref->[1]" ) {
            $err = '密码错误';
        } else {
            session 'logged_in' => $name;
            redirect '/';
        };
    };
    template 'login', { 'err' => $err, };
};

any['get', 'post'] => '/register' => sub {
    my $err;
    if ( request->method() eq 'POST' ) {
        my $name = params->{username};
        my $passwd = params->{password};
        my $check_sth = database->prepare(
            'select count(name) from ops_user where name = ?'
        );
        $check_sth->execute($name);
        my $ref = $check_sth->fetchrow_arrayref;
        if ( "$ref->[0]" == '0' ) {
            my $insert_sth = database->prepare(
                'insert into ops_user (name,passwd) value(?,?)'
            );
            $insert_sth->execute($name, md5_hex($passwd));
            $err = '等待人工审核通过,3Q';
        } else {
            $err = '该用户名已注册';
        };
    };
    template 'register', { 'err' => $err, };
};

get '/' => sub {
    template 'index';
};

get '/logout' => sub {
    session->destroy;
    redirect '/';
};

sub _snmp_check {
    my $app = shift;
    my $list = {};
#之前通过use加载了plugin::database，所以直接有database对象引用了
    my $sth = database->prepare(
        'select channel,intranet from myhost where application = ?',
    );
    $sth->execute($app);
    while (my $ref = $sth->fetchrow_hashref()) {
        $list->{"$ref->{'channel'}"} = [] unless exists $list->{"$ref->{'channel'}"};
        my $ip = $ref->{'intranet'};
        my @snmpstat = _snmp_walk("$ip");
#这里第一是没想到比较好的把每个ip的各项检查结果导出的办法；所以干脆采用固定次序输出；
#第二是因为unshift很耗资源，所以先push再reverse
        push @snmpstat, $ip;
        @snmpstat = reverse @snmpstat;
        push @{$list->{"$ref->{'channel'}"}}, \@snmpstat;
    }

    push my @checkstat, map{
        { channel => $_,
          host    => $list->{"$_"},
        }
    } keys %{$list};
    return \@checkstat;
};

sub _snmp_walk {
    my $o_host = shift;
    my $o_community = 'public';
    my $result = {};
    my %oids = (
        'cacheUptime'                  => '.1.3.6.1.4.1.3495.1.1.3.0',
        'cacheProtoClientHttpRequests' => '.1.3.6.1.4.1.3495.1.3.2.1.1.0',
        'cacheNumObjCount'             => '.1.3.6.1.4.1.3495.1.3.1.7.0',
        'cacheCurrentUnusedFDescrCnt'  => '.1.3.6.1.4.1.3495.1.3.1.10.0',
        'cacheClients'                 => '.1.3.6.1.4.1.3495.1.3.2.1.15.0',
        'cacheHttpMissSvcTime'         => '.1.3.6.1.4.1.3495.1.3.2.2.1.3.1',
        'cacheRequestHitRatio'         => '.1.3.6.1.4.1.3495.1.3.2.2.1.9.1',
        'cacheRequestByteRatio'        => '.1.3.6.1.4.1.3495.1.3.2.2.1.10.1',
    );

    my ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
        -community => $o_community,
#默认是5秒超时，如果有没开snmp的，这页面打开时间一下就上去了，所以要调短
        -timeout   => 1,
    );
    if (defined $session) {
        $session->translate(Net::SNMP->TRANSLATE_NONE);
        my $squid_status = $session->get_request( -varbindlist => [$oids{'cacheUptime'}, $oids{'cacheProtoClientHttpRequests'}, $oids{'cacheNumObjCount'}, $oids{'cacheCurrentUnusedFDescrCnt'}, $oids{'cacheClients'}, $oids{'cacheHttpMissSvcTime'}, $oids{'cacheRequestHitRatio'}, $oids{'cacheRequestByteRatio'}, ], );
        $session->close;
        if (defined $squid_status) {
#如果要算当前的rps，那得sleep 1再取一次，对几十台集群监控来说不可取；
#姑且用总的平均值做个衡量，或许可以采用二八法则估算一个高峰时间的rps；
#注意这个cacheUptime是保留两位ms的，所以算rps的时候要除以100；
#上述原因也是一般大家对单机squid监控采用rrd的原因，采用COUNTER32数据源，直接递增显示。
            my $request_sum = $squid_status->{"$oids{'cacheProtoClientHttpRequests'}"};
            my $uptime = $squid_status->{"$oids{'cacheUptime'}"};
            return $request_sum / $uptime * 100, $squid_status->{"$oids{'cacheNumObjCount'}"}, $squid_status->{"$oids{'cacheCurrentUnusedFDescrCnt'}"}, $squid_status->{"$oids{'cacheClients'}"}, $squid_status->{"$oids{'cacheHttpMissSvcTime'}"}, $squid_status->{"$oids{'cacheRequestHitRatio'}"}, $squid_status->{"$oids{'cacheRequestByteRatio'}"};
        };
    };
};

true;```
修改cachemoni/config.yml如下：
```yaml
appname: "cachemoni"
layout: "main"
charset: "UTF-8"
#采用TT作为view模板，注意tt默认是[%%]，而dancer里是<%%>，所以另外要定义标签
template: "template_toolkit"
engines:
  template_toolkit:
    encoding:  'utf8'
    start_tag: '[%'
    end_tag:   '%]'
#用默认的Simple，即存在内存的一个hash里，实际效果很不稳定，改用yaml，但也有yml文件在关闭浏览器后依旧存在的问题。
session: "YAML"
session_dir: "/tmp/dancer_session_dir"
session_expires: 300
plugins:
  Database:
    driver: 'mysql'
    database: 'myops'
    host: '10.1.1.25'
    username: 'user'
    password: 'password'
    connection_check_threshold: 10
    dbi_params:
      RaiseError: 1
      AutoCommit: 1
    on_connect_do: ["SET NAMES 'utf8'", "SET CHARACTER SET 'utf8'" ]
    log_queries: 1```
创建cachemoni/views/monitor.tt如下：
```html[% IF session.logged_in %]
[% FOREACH stat IN status %]
  <hr> channel: [% stat.channel %]
  <table width="100%" cellspacing="0" cellpadding="0" border="1">
  <tr>
  [% FOREACH col IN name %] 
    <th><center>
    [% col %]
    </center></th>
  [% END %]
  </tr>
  [% FOREACH host IN stat.host %]
    <tr>
    [% FOREACH list IN host %]
      <td>
      [% list %]
      </td>
    [% END %]
  [% END %]
  </tr></table>
[% END %]
[% ELSE %]
  内部信息，请登陆后查看
[% END %]```
创建cachemoni/views/login.tt如下：
```html
<center>
<h2>登陆页面</h2>
[% IF err %]<p class=error><strong>Error:</strong> [% err %][% END %]
<form action="/login" method=post>
  <dl>
    <dt>用户名:
    <input type=text name=username>
    <dt>密  码:
    <input type=password name=password>
    <dd><input type=submit value=login>
  </dl>
</form>
</center>```注册页面类似，不贴了。
然后是layout层的共用部分，之前定义了是views/layouts/main.tt，如下：
```html……
<body>
<div class=metanav>
  <a href="/">首页</a> | 
  [% IF not session.logged_in %]
    <a href="/register">注册</a> | 
    <a href="/login">登陆</a>
  [% ELSE %]
    <a href="/logout">退出</a>
  [% END %]

[% content %]
<div id="footer">
Powered by <a href="http://perldancer.org/">Dancer</a> [% dancer_version %]

</body>
</html>```
这里修改了<%%>为[%%]，其他的tt模版也要改。
然后运行perl cachemoni/bin/app.pl，启动3000端口的监听，访问一下如下：
<img src="/images/uploads/squid-monitor-demo.jpg" alt="" title="123" width="571" height="401" class="alignnone size-full wp-image-2505" /></a>
这就算完成一个小的网页了，然后开始配置进apache：
```bashcpanm Plack::Handler::Apache2
wget http://search.cpan.org/CPAN/authors/id/P/PH/PHRED/mod_perl-2.0.5.tar.gz
tar zxvf mod_perl-2.0.5.tar.gz
cd mod_perl-2.0.5
perl Makefile.PL
然后会提示输入apxs的全路径：/usr/local/apache2/bin/apxs
make && make install
sed -i s'/LoadModule/i\LoadModule perl_module modules/mod_perl.so\' /usr/local/apache2/conf/httpd.conf
cat >> /usr/local/apache2/conf/httpd.conf <<EOF
<VirtualHost *:80>
        ServerName dancer.test.china.com
        DocumentRoot /www/html/cachemoni
        <Directory /www/html/cachemoni>
            AllowOverride None
            Order allow,deny
            Allow from all
        </Directory>
        <Location />
            SetHandler perl-script
            PerlHandler Plack::Handler::Apache2
            PerlSetVar psgi_app /www/html/cachemoni/bin/app.pl
        </Location>
</VirtualHost>
EOF
/usr/local/apache2/bin/apachectl restart
```
访问一下，OK~
各种和webserver搭配的方法（其实就是两种：mod_perl和各种cgi）详见：<a href="http://search.cpan.org/~sukria/Dancer-1.3060/lib/Dancer/Deployment.pod">CPAN文档</a>
