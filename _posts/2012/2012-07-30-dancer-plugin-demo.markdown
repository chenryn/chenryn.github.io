---
layout: post
title: 一个Dancer::Plugin的实例
category: dancer
tags:
  - perl
---
公司内部工具统一使用passport认证登录，于是写这么一个小plugin，用来给dancer做的网站使用统一认证。
passport的原理很简单，将原先的页面url带入session转到passport的login，然后由passport通过user/password或者kerberos确认是否正确，并返回一个ticket参数，然后拿这个ticket再到passport的verify上校验一次username，正确的话写入session即可。代码如下：
```perl
package Dancer::Plugin::Auth::Passport;
use Dancer ':syntax';
use Dancer::Plugin;
use Furl; 
use warnings;
use strict;

our $VERSION = '0.01';

my $settings = plugin_setting;
my $PASSPORT_HOST = $settings->{passport_host} || 'passport.company.com';

sub _auth_passport {
    if ( !session('username') ) {
        my $req_url = request->scheme .'://'. request->header('Host') . request->uri;
        if ( defined(my $ticket = params->{'ticket'}) ) {
            my $passport_url = "https://${PASSPORT_HOST}/verify.php?t=${ticket}";
            my $furl = Furl->new( timeout => 10, headers => ['Referer' => "$req_url"] );
            my $res = $furl->get($passport_url);
            redirect "https://${PASSPORT_HOST}/login.php?forward=${req_url}" unless $res->is_success;
            session username => $res->content;
            redirect session->{'original_url'};
        } else {
            session original_url => ${req_url};
            redirect "https://${PASSPORT_HOST}/login.php?forward=${req_url}";
        };
    };
};

register 'auth_passport' => \&_auth_passport;
register_plugin;

true;
__END__
```

使用方法如下：

```perl
    package DancerApp;
    use Dancer ':syntax';
    use Dancer::Plugin::Auth::Passport;
    hook 'before' => sub { auth_passport };
    get '/' => sub { return 'Hello Passport' };
    true;
```

完毕。
