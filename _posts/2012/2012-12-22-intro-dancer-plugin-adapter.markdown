---
layout: post
title: Dancer::Plugin::Adapter 模块介绍
category: dancer
---
Dancer 活跃的社区和强大又方便的插件开发导致出现了太多好玩的插件，有位新同学在刚上手的这两周内就已经往 CPAN 提交了四个插件了。

今天这里介绍一个刚在 IRC 上被推荐的东东，额，这个插件的作者跟上面提到的同学说：大哥，看看偶这个模块吧，就不用你这么辛苦的啥都写新插件了。

[Dancer::Plugin::Adapter](https://metacpan.org/module/Dancer::Plugin::Adapter) 模块的作用，就是当你的项目需要在多处使用某个模块的时候，不用频繁的到处去new，直接在 config.yml 里一定义，它会自动给你实例化成 `Dancer::Object`，然后缓存住，你就可以直接用 service 关键词调用了。

用法示例：

{% highlight perl %}
    # in config.yml
    plugins:
      Adapter:
        ua:
          class: HTTP::Tiny
          options:
            max_redirect: 3
        postmark:
          class: WWW::Postmark
          options: POSTMARK_API_TEST
     
    # in your app
    use Dancer::Plugin::Adapter;
    get '/' => sub {
      eval {
        service("postmark")->send(
          from    => 'me@domain.tld',
          to      => 'you@domain.tld, them@domain.tld',
          subject => 'an email message',
          body    => "hi guys, what's up?"
        );
      };
      return $@ ? "Error: $@" : "Mail sent";
    };
    get '/proxy/:url' => sub {
      my $res = service('ua')->get( params->{'url'} );
      if ( $res->{success} ) {
        return $res->{content};
      }
      else {
        template 'error' => { response => $res };
      }
    };
{% endhighlight %}

话说我还是喜欢上代码，不喜欢完整的翻译 POD 啊…………
