---
layout: post
theme:
  name: twitter
title: 一个Plack::Middleware的实例
category: dancer
tags:
  - perl
---
做一个文件上传的网页，想稍微华丽一点，显示进度条出来。在Apache和Catalyst下都有现成的模块，不过Dancer上还没有。看了一下代码，Dancer::Request里没有像Catalyst那样暴露prepare_body_chunk方法。所以需要在plack上利用psgi.input来做。尽量重用现有代码，所以progress.css和progress.js都直接从Catalyst/Plugin/UploadProgress/example/Upload/root/static/里复制。
```perl
package Plack::Middleware::UploadProgress;
use strict;
use CHI;
use Carp;
use HTTP::Body;
use Plack::Request;
use Plack::TempBuffer;
use parent qw(Plack::Middleware);

sub call {
    my ( $self, $env ) = @_;
    my $rm = $env->{REQUEST_METHOD};
    my $ct = $env->{CONTENT_TYPE};
    my $cl = $env->{CONTENT_LENGTH};
    if ( $rm =~ m#^post$#i and (
         $ct =~ m#^application/x-www-form-urlencoded#i or
         $ct =~ m#^multipart/form-data#i )
     ) {
        my $cache = CHI->new( driver => 'Memory', global => 1 );
        my $req = Plack::Request->new($env);
        my $id = $req->param('progress_id');

        my $body = HTTP::Body->new($ct, $cl);
        $env->{'plack.request.http.body'} = $body;
        $body->cleanup(1);
        my $input = $env->{'psgi.input'};
        my $buffer;
        if ($env->{'psgix.input.buffered'}) {
            $input->seek(0, 0);
        } else {
            $buffer = Plack::TempBuffer->new($cl);
        }

        my $spin = 0;
        while ($cl) {
            $input->read(my $chunk, $cl < 8192 ? $cl : 8192);
            my $read = length $chunk;
            $cl -= $read;
            $body->add($chunk);
            $buffer->print($chunk) if $buffer;

            my $progress = $cache->get('upload_progress_' . $id);
            if ( !defined $progress ) {
                $progress = {
                    size     => $body->content_length,
                    received => length $chunk,
                };
                $cache->set( 'upload_progress_' . $id, $progress );
            } else {
                $progress->{received} += $read;
                $cache->set( 'upload_progress_' . $id, $progress );
            };

            if ($read == 0 && $spin++ > 2000) {
                Carp::croak "Bad Content-Length: maybe client disconnect? ($cl bytes remaining)";
            }
        };

        if ($buffer) {
            $self->env->{'psgix.input.buffered'} = 1;
            $self->env->{'psgi.input'} = $buffer->rewind;
        } else {
            $input->seek(0, 0);
        }

    };

    my $res = $self->app->($env);
    return $res;
}

true;
```

上面的代码，progress部分基本摘抄自Catalyst::Plugin::UploadProgress模块，chunk部分基本摘抄自Plack::Middleware::CSRFBlock模块，当然它也基本摘抄自Plack::Request模块~~
上面写的不全，没有关于GET /progress?progress_id=*的json输出处理。不过这部分也可以在DancerApp.pm里直接写get '/progress' => sub {};，最后申明，这代码刚写完，没测……CHI或许应该用memcached而不是memory~

在DancerApp/bin/app.pl里这么配置：
```perl
use Dancer;
use DancerApp;
use Plack::Builder;

my $app = sub {
    my $env = shift;
    my $req = Dancer::Request-new( env => $env );
};

builder {
    enable "Plack::Middleware::UploadProgress";
    $app;
};

dance;
```
