---
layout: post
title: 学习 Dancer::Plugin::Auth::Extensible 模块
category: dancer
---
首先介绍一下 `Dancer::Plugin::Auth::Extensible` 模块。这是一个认证验证的框架，之前 Dancer 里这方面的框架是 RBAC ，不过 RBAC 是实现的 auth 对象，然后提供 `->asa`，`->can`，`->roles` 等方法。在使用的时候，需要自己在每个 route 里写 if 或者 switch 代码，显得比较繁琐。而 Extensible 模块提供了另一个（或者说是两个）思路。同时借此深入了解 `Dancer::Plugin` 和 `Dancer::Hook` 的用法，外加熟悉 perl 的一些不常见的对象使用。收获良多，不可不记。

上面之所以说算是两个思路。是因为在这个模块出来的短短十天内，其 0.001 和 0.010 版本已经完全从实现到使用方法都变了样子。下面先说 0.001 版。

这个原始版本的使用方法大概是这样的：

{% highlight perl %}
    get '/secret' => sub :RequireRole(God) { DestroyWorld(); };
    get '/users' => sub :RequireLogin {
        my $user = logged_in_user;
        return "Hi there, $user->{username}";
    };
{% endhighlight %}

哇，我是第一次见到在 `sub` 后面还可以写这样的东西（好吧，暴露了本人的菜鸟本质）！赶紧打开模块的源代码，然后找到了相关的几行：

{% highlight perl %}
    use attributes;
    use Scalar::Util;
    use Exporter 'import';
    our @EXPORT=qw(MODIFY_CODE_ATTRIBUTES FETCH_CODE_ATTRIBUTES);
    hook before => sub {
        my $route_handler = shift || return;
        my $requires_login = get_attribs_by_type(
            'RequireLogin', $route_handler->code
        );
        my $roles_required = get_attribs_by_type(
            'RequireRole', $route_handler->code
        );
        ...;
    };
    my %attrs;
    sub MODIFY_CODE_ATTRIBUTES {
        my ($package, $subref, @attrs) = @_;
        $attrs{ refaddr $subref } = \@attrs;
        return;
    } 
    sub FETCH_CODE_ATTRIBUTES {
        my ($package, $subref) = @_;
        my $attrs = $attrs{ refaddr $subref };
        return $attrs ? @$attrs : ();
    }
    sub get_attribs_by_type {
        my ($type, $coderef) = @_;
        return unless $coderef;
        my @desired_attribs = grep { 
            /^$type(?:\([^)]*\))?$/ 
        } attributes::get($coderef);
        return if !@desired_attribs;
        return [
            map {
                my $f = $_;
                $f =~ s/^$type\(\s*([^)]*)\s*\)$/$1/;
                split(/\s+/, $f);
            } @desired_attribs
        ];
    }
{% endhighlight %}

代码中的 `$route_handler->code` 就是应用中写的 `sub {}`。__整个代码中，最关键的部分是这句 `attributes::get($coderef)` ！__

首先有个小问题，因为 Dancer 里，get 是关键词，所以这里写了全路径。`attributes::get` 的介绍见 [POD](https://metacpan.org/module/attributes#Available-Subroutines)，大意是会使用 `FETCH_type_ATTRIBUTES` 方法获取列表。因为这里 attribute 是 sub 的，所以 type 就是 CODE ，也就是用前面定义的 `FETCH_CODE_ATTRIBUTES`。`FETCH_type_ATTRIBUTES` 方法的说明见 [POD](https://metacpan.org/module/attributes#Package-specific-Attribute-Handling)。

在<https://metacpan.org/module/perlsub#Subroutine-Attributes>中，建议我们看另一个更好用的模块来理解自定义属性的问题，这个模块是[Attribute::Handlers](https://metacpan.org/module/Attribute::Handlers)。

然后是 0.010 版：

新版本的使用方法如下：

{% highlight perl %}
    get '/secret' => require_any_role [qw(God Admin)] => sub { DestroyWorld(); };
    get '/users' => require_login => sub {
        my $user = logged_in_user;
        return "Hi there, $user->{username}";
    };
{% endhighlight %}

这种添加新关键词的写法更加的 dancer。所以能从实现中学到更有普适性的 `Dancer::Plugin` 开发方法。摘要代码如下：

{% highlight perl %}
    use Dancer::Plugin;
    use Dancer qw(:syntax);
    sub require_any_role {
        return _build_wrapper(@_, 'any');
    }
    register require_any_role  => \&require_any_role;
    sub _build_wrapper {
        my $require_role = shift;
        my $coderef = shift;
        my $mode = shift;
        my @role_list = ref $require_role eq 'ARRAY' 
            ? @$require_role
            : $require_role;
        return sub {
            my $user = logged_in_user();
            if (!$user) {
                execute_hook('login_required', $coderef);
                return redirect $loginpage;
            }
            my $role_match;
            if ($mode eq 'single') {
                $role_match++ if user_has_role($require_role);
            } elsif ($mode eq 'any') {
                my %role_ok = map { $_ => 1 } @role_list;
                for (user_roles()) {
                    $role_match++ and last if $role_ok{$_};
                }
            } elsif ($mode eq 'all') {
                $role_match++;
                for my $role (@role_list) {
                    if (!user_has_role($role)) {
                        $role_match = 0;
                        last;
                    }
                }
            }
            if ($role_match) {
                return $coderef->();
            }
            execute_hook('permission_denied', $coderef);
            return redirect $deniedpage;
        };
    }
    register_hook qw(login_required permission_denied);
{% endhighlight %}

主要摘要了几个部分：

* 第一，register

摘要中就是 register 了一个关键词 require\_any\_role 。这样在启用了本 plugin 的应用里，你可以直接使用这个关键词。至于具体的 sub，没有什么特殊的。看前面的用法举例就知道了，传递一个 roles 的数组引用(或者单个role的话就是字符串，这个在后面有判断)和一个 sub 作为参数，也就是 `@_`。

* 第二，register\_hook

第一个是 `Dancer::Plugin` 的部分，第二个是 `Dancer::Hook` 的功能。注册一个叫 login\_required 的 hook，然后在需要的地方运行 `execute_hook('login_required', $coderef)`。

`register_hook` 接受 `$name` 和 `$coderef` 参数。如果只有 name 的话，`Dancer::Hook` 里也会自动生成一个 `$compiled_filter` ，作用就是除非你调用 `halt` 了，不然就输出一条 core 级别的日志(这里其实还用到了 `Dancer::Hook::Properties`，判断是否需要运行，默认初始化参数空的时候返回真，不运行 app，继续往下到记录日志)。然后，将这个对象传递给 `Dancer::Factory::Hook`。这里会把前面的生成的 coderef 加入到一个 `$class->hooks->{$hook_name}` 数组，而 name 加入到 `$self->registered_hooks` 数组。

在`execute_hook` 的时候，从前面的 `$self->registered_hooks` 判断是否有这个 name，然后从 `$class->hooks->{$hook_name}` 里依次取出全部 coderef 执行。

* 第三，any

和前面 0.001 类似，这里也有一个关键词冲突的问题，前面的 get 和这里的 any 都是 `Dancer` 的关键词。不然的话，其实这里使用 `Perl6::Junction` 或者 `Syntax::Keyword::Junction` 模块是正当其时啊。我之前都用 `Perl6::Junction`，不过昨天的 Perl Advent Calendar 文章里推荐了后面这个 `Syntax::Keyword::Junction`，[meta::cpan](https://metacpan.org) 上也都是两个喜欢。另外题外话说一句，那篇文章里推荐的另一个 [Function::Parameters](https://metacpan.org/module/Function::Parameters) 可真是好东西，唯一问题是低于 Perl 5.014的版本用不了，因为他不是 source filter 而是 keyword plugin api 的。这是新版本的功能。

--------------

__12 月 30 日附：__

在 github 上提交了一个短短的 patch ，给 DPAE 加上了 正则匹配 role 的功能，感谢 Perl5.10的强大，代码其实就修改一行足以实现：

{% highlight perl %}
    lib/Dancer/Plugin/Auth/Extensible.pm @ 891cd02
    @@ -266,7 +266,9 @@ sub _build_wrapper {
             my $role_match;
             if ($mode eq 'single') {
    -            $role_match++ if user_has_role($require_role);
    +            for (user_roles()) {
    +                $role_match++ and last if $_ ~~ $require_role;
    +            }
             } elsif ($mode eq 'any') {
                 my %role_ok = map { $_ => 1 } @role_list;
                 for (user_roles()) {

    t/01-basic.t @ 891cd02
    @@ -81,6 +81,9 @@ response_status_is [ GET => '/allroles' ], 200,
     response_status_is [ GET => '/regex/a' ], 200,
         "We can request a regex route when logged in";
     
    +response_status_is [ GET => '/piss/regex' ], 200,
    +    "We can request a route requiring a regex role we have";
    +
     # ... but can't request something requiring a role we don't have
     response_redirect_location_is  [ GET => '/piss' ],
         'http://localhost/login/denied?return_url=%2Fpiss',

    t/lib/TestApp.pm @ 891cd02
    @@ -39,6 +39,10 @@ get '/piss' => require_role BearGrylls => sub {
         "You can drink piss";
     };
     
    +get '/piss/regex' => require_role qr/beer/i => sub {
    +    "You can drink piss now";
    +};
    +
     get '/anyrole' => require_any_role ['Foo','BeerDrinker'] => sub {
         "Matching one of multiple roles works";
     };
{% endhighlight %}
