---
layout: post
title: 【Message::Passing系列】客户端收集脚本
category: logstash
tags:
  - perl
  - message-passing
---

最后编写一段日志收集的agent：
```perl
    #!/usr/bin/perl
    package NginxLogCollector;
    use Moo;
    use MooX::Options;
    use Message::Passing::DSL;
    use MooX::Types::MooseLike::Base qw/ Str /;
    use namespace::clean -except => [qw( meta _options_data _options_config )];
    with 'Message::Passing::Role::Script';
    option filename => (
        is => 'ro',
        isa => Str,
        default => sub { '/data/nginx/logs/access.log' },
    );
    option rabbitmq => (
        is => 'ro',
        isa => Str,
        default => sub { '10.3.18.199' },
    );
    sub build_chain {
        my $self = shift;
        message_chain {
            output rabbitmq => (
                class => 'AMQP',
                exchange_name => 'logcollect',
    # 目前测试结果，发现Input::AMQP无法接收到非topic的exchange
    # CPAN上有关RabbitMQ的模块都是这个哥们写的，POD简略到没有一样，表示无语下
    #            exchange_type => 'direct',
                hostname => $self->rabbitmq,
                username => 'guest',
                password => 'guest',
            );
            output debug => (
                class => 'STDOUT',
            );
            encoder("encoder",
                class => 'JSON',
                output_to => 'rabbitmq',
                output_to => 'debug',
            );
            filter grok => (
                class => 'GrokLike',
                output_to => 'encoder',
            );
            filter logstash => (
                class => 'ToLogstash',
                output_to => 'grok',
            );
            decoder("decoder",
                class => 'JSON',
                output_to => 'logstash',
            );
            input nginxlog => (
                class => 'FileTail',
                output_to => 'decoder',
                filename => $self->filename,
           );
        };
    }
    __PACKAGE__->start unless caller;
    1;
```
目前就做到这步，之后从rabbitmq里往elasticsearch写的还没搞。从上面的chain可以很清除的看到和logstash一样的管道思想，input->decoder->filter->encoder->output。巧的是两种写法中，decode/encode那个写法跟puppet的DSL定义特别的像。哈哈～

继续贴汇总入库的agent代码：
```perl
#!/usr/bin/perl
use Moo;
use MooX::Options;
use Message::Passing::DSL;
use MooX::Types::MooseLike::Base qw/ Str /;
use namespace::clean -except => [qw( meta _options_data _options_config )];

with 'Message::Passing::Role::Script';

option elasticsearch_servers => (
    is => 'ro',
    isa => Str,
    default => sub { '10.3.18.199:9200' },
);

option rabbitmq => (
    is => 'ro',
    isa => Str,
    default => sub { '10.3.18.199' },
);

sub build_chain {
    my $self = shift;
    message_chain {
        output elasticsearch => (
            class => 'ElasticSearch',
            elasticsearch_servers => [$self->elasticsearch_servers],
        );
        decoder decoder => (
            class => 'JSON',
            output_to => 'elasticsearch',
        );
        input rabbitmq => (
            class => 'AMQP',
            exchange_name => 'logcollect',
            queue_name => 'logcollect',
            hostname => $self->rabbitmq,
            username => 'guest',
            password => 'guest',
            output_to => 'decoder',
        );
    };
}
__PACKAGE__->start unless caller;
1;
```
总的来说，原有模块相互之间都有些不太协调，用的时候还是要自己改改。比如这里，原版的Output::ElasticSearch是吧之前传递过来的整个message放进@fields里的，这跟Filter::ToLogstash的message结构是完全冲突的。所以需要修改Output::ElasticSearch里的bulk_index()的data=>$data,就可以了，不要多改动。

整个代码变动，参加个人github:<https://github.com/chenryn/Message-Passing.git>
