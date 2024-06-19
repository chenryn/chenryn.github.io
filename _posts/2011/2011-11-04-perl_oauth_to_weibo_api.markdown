---
layout: post
theme:
  name: twitter
title: 用perl调用新浪微博API小实验
date: 2011-11-04
category: dancer
tags:
  - perl
  - oauth
---

新浪微博API是通过OAuth方式的。perl上有现成的模块，只需要稍微调一下参数就行了。下午比较闲，试试看。。。
一般网上说的，都还是Net::OAuth模块，这个是1.0a版本的，一看perldoc那个长篇就头疼。这里我用Net::OAuth2模块，简单方便，而且正好配合dancer框架，方便做外部网站应用。
首先是安装模块：
```perlcpanm --mirror-only --mirror http://mirrors.163.com/cpan LWP::Protocol::https Net::OAuth2::Client```
因为新浪微博的api用的是https协议，所以要加上LWP::Protocol::https模块，这样才能发起443请求。
然后在web/lib/weibo.pm里里添加如下语句：
```perluse Net::OAuth2::Client;
use JSON qw(decode_json);        #只需要decode_json，因为dancer自己有from_json和to_json，不要覆盖了

get '/oauth' => sub {        #这个url是对外发布的地址，用来跳转到微博开放平台验证是否授权。
    my $client = &test_client;
    redirect $client->authorize_url;
};

get '/oauth/callback' => sub {        #这个url是授权返回地址，真正的应用入口。
    my $client = &test_client;
#这个code参数是前面的authorize_url授权验证后返回时带上的，使用这个code进行access token验证。
#所以无法直接访问/oauth/callback，必须通过/oauth访问。
    my $access_token = $client->get_access_token(params->{code});
#access token验证通过后，真正的对api发起请求，列表见http://open.weibo.com/wiki/API文档_V2
#请求方法有get/post/delete等，见Net::OAuth2::AccessToken模块。
    my $response = $access_token->get('/2/statuses/user_timeline.json');
    if ( $response->is_success ) {
        my $data = decode_json $response->decoded_content;
        template 'weibo', { msgs => $data };
#        return $data->{'statuses'}->[0]->{'text'};
    } else {
        return $response->status_line;
    };
};

sub test_client {
    Net::OAuth2::Client->new(
        config->{app_key},
        config->{app_secret},
        user_agent => LWP::UserAgent->new(ssl_opts => {SSL_verify_mode => '0x01'}),
        site => 'https://api.weibo.com',
        authorize_path => '/oauth2/authorize',
        access_token_path => '/oauth2/access_token',
        access_token_method => 'POST',
    )->web_server(
        redirect_uri => uri_for('/oauth/callback')  #注意这个url需要去新浪授权，否则验证cb地址不匹配会报错的. 
    );
};```
然后在config.yml里定义好从新浪微博开放平台里申请应用给的key和secret就行了。

这里跟模块里提供的demo主要有几点不一样的地方：

 第一个是test_client必须赋值给变量，不知道为啥demo里不用？
 第二个是Net::OAuth2::Client->new里，需要自己创建useragent，默认的useragent只是LWP::UserAgent->new，没有ssl_opts，这样会在callback的时候反馈ssl验证有问题。
 第三个是access_token_method，虽然新浪的开发文档上写的GET，但实际只能用POST。

最后，测试成功返回了json数据，<del datetime="2011-11-05T07:33:45+00:00">但是还有两个问题：
 第一，直接return $data->{'statuses'}->[0]->{'text'};看到的是乱码，应该是content编码设置问题；</del>
 第二，使用template如下：
```perl<% FOREACH status IN msgs.statuses %>
when: <% status.created_at %><br />
text: <% status.text %><br />
from: <% status.source %><br />
user: <% status.user.name %><br />
city: <% status.user.location %><br />
<hr />
<% END %>```
<del datetime="2011-11-04T11:01:17+00:00">但是访问页面http://chenlinux.com:8080/oauth后跳转到页面显示的居然还是HASH(0X1234)这样的地址。奇怪了。先记录一下，有空继续调……</del>
<strong>补充：第二个问题解决了，原因居然是config.yml里忘了用TT模版，simple模板不会for循环的……
继续补充：第一个问题也解决了，原因是不能直接用from_json，而要用decode_json。</strong>
效果如下：
<img src="/images/uploads/weibo_api.png" alt="" title="weibo_api" width="601" height="370" class="alignnone size-full wp-image-2683" />
