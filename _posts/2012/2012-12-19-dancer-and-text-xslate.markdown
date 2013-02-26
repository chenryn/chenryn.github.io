---
layout: post
title: Dancer 框架使用 Text::XSlate 模版的注意事项
category: dancer
---
Dancer 框架自带有一个 Simple 模版，不过推荐使用 `Template` 模块作为替代品。不过从性能上来说，TT2 比之前博客里陆续介绍过的 `HTML::Template` 和 `Text::MicroTemplate` 都要差。而这方面最好的，就是 `Text::XSlate` 模块了。今天尝试将一个 Dancer 应用迁移到 `Text::XSlate` 上。踩进两个坑，特此记录。

关于语法什么的，可以看 POD ，扶凯 有翻译的 中文版POD 。足以十分钟入门。就不多说了。

* 第一个坑：session 的处理

website 少不了 session 的运用。在 template 里使用 `[% session.username %]` 可以很方便的控制显示面板还是登陆啊什么的。

不过切换成 XSlate 后（即 `<: $session.username :>`），请求会 crash 掉，报错大意是: __$session 没有 username 这个 method__。

XSlate 提供了 `dump` 语法糖，让我们可以直接使用 `<: $session | dump :>` 检查问题。这时候发现显示如下：

{% highlight perl %}
    $VAR1 = { blessed( { id => '2131232131', username => 'user1' } ), Dancer::Session::YAML };
{% endhighlight %}

尝试使用 `<: $session.id :>` ，发现可以正常输出 2131232131 。

进去看 `Dancer::Session` 的代码，原来在 `Dancer::Session::Abstract` 里，有这么一行：

{% highlight perl %}
    __PACKAGE__->attributes('id');
{% endhighlight %}

说实话不太理解这行的用法，不过不妨碍我们用简单办法解决问题…… 在我们的应用中给 `Dancer::Session::YAML` 定义一个叫 username 的 method 就可以骗过去了：

{% highlight perl %}
    package DancerApp;
    use Dancer ':syntax';
    use Dancer::Session::YAML;
    
    sub Dancer::Session::YAML::username {
        return session('username');
    };
    
    use Dancer::Plugin::Auth::Extensible;
    get '/' => sub :RequireLogin { template 'index' };
    ...;
    
    true;
{% endhighlight %}

* 第二个坑：flashmessage 的处理

这是一个外加模块，叫做 `Dancer::Plugin::FlashMessage` 。用它配合模版的 layout 功能，可以很方便的给应用提供全局的消息通知。使用方法如下：

首先在模块里加载 flash 变量：

{% highlight perl %}
    package DancerApp::First;
    use Dancer ':syntax';
    use Dancer::Plugin::FlashMessage;
    use Dancer::Plugin::Auth::Extensible;
    
    get '/first/:name' => sub :RequireRole('MAN') {
        flash message => 'Hello! You are the first man here.';
        template 'first', { name => param('name') };
    };
    
    true;
{% endhighlight %}

然后在模版里判断显示：

{% highlight html %}
    [% IF flash.message %]
      <div class="alert alert-success">
        [% flash.message %]
      </div>
    [% END %]
{% endhighlight %}

同样，在修改成 XSlate 后，模版是这样：

{% highlight html %}
    : if $flash.message {
      <div class="alert alert-success">
        <: flash.message :>
      </div>
    : }
{% endhighlight %}

结果发现页面上的 div 一直保持，而且显示着 `CODE(0x39a5c30)` 这样的字样。同样使用 `dump` 语法糖，看到 `$flash` 其实是 `{ message => sub {"DUMMY"} }`。

这个就有趣了，居然是个代码段~~于是翻源码来看：

{% highlight perl %}
    hook before_template => sub {
        shift->{$token_name} = {
            map { my $key = $_; my $value;
                ( $key, sub { defined $value and return $value;
                    my $flash = session($session_hash_key) || {};
                    $value = delete $flash->{$key};
                    session $session_hash_key, $flash;
                    return $value;
                } );
            } ( keys %{session($session_hash_key) || {} })
        };
    };
{% endhighlight %}

`map` 里面，确实是一个 `$key => sub {}` 。

这个时候我切换两个 template 做了个测试。在里面那个匿名 sub 里写了一行 `die;`。结果。XSlate “正常”运行过去，在页面上显示前面说过的 `CODE()`；而在 Template 模版下，500 了。看 console 的日志，发现 `die` 这个动作不是在 `before_template` 阶段发生的。而是在随后的 render 阶段，`Dancer::Template::Abstract` 里才挂了。

所以，最终，两个坑归结起来并成了一个问题：模版系统是支持 coderef 还是支持 object 的问题。就在我写着这句话的同时，IRC 上还为 `Dancer::Plugin::FlashMessage` 的新实现而争论不休。xdg 童鞋已经在我提问的一个小时内快速的搞出来一个把 flash "object 化"的 patch，而 bigpresh 童鞋坚定的认为应该把 `delete` 操作放在 `hook after_template` 里完成。原作者 `dams` 则"相信"更多的模版是支持 coderef 不支持 object 的。

不过我觉得，其实改动最小的办法，就是别用 `map` 这么高档的语法。拆成两段处理，确保传递给 `template_render` 的是字符串即可：

{% highlight perl %}
    hook before_template => sub {
        my %hash;
        my $flash = session($session_hash_key) || {};
        for ( keys %{$flash} ) {
            $hash{$_} = delete $flash->{$_};
        };
        session $session_hash_key, $flash;
        shift->{$token_name} = \%hash;
    };
{% endhighlight %}

最后的最后，就在我测试完我的改动版本在两种模版下都可以运行的时候，dams 已经决定先同时保持 coderef 和 object 的写法并提供 setting 配置。然后慢慢搜集各种模版系统做覆盖测试。

__20 日增__

最后最后的最后，在 github 上搜到两个用 dancer 和 xslate 写的 repo。他们都采用了在应用 app 里自定义 `hook before_template` ，把 `session('username')` 和 `flash('message')` 两个变量传递给 `$token` 哈希的办法。
