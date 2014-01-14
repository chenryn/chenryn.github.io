---
layout: post
title: Coro::Semaphore和async_pool示例
category: testing
tags:
  - perl
---
之前有一个[AnyEvent和Fork写的http压测工具](http://chenlinux.com/2012/07/19/anyevent-fork-http-load-runner-demo/)，评论里有大神教导说用Coro控制并发更有效更方便。于是改写了下面的版本。从被压测的nginx server上，可以看到ESTABLISHED的数量确实大大增加，“”并发”两个字算是做到了。

先上普通的Coro::Semaphore控制并发的代码：
{% highlight perl %}
# 之前的fork和count部分完全一致，不重复帖了。
sub coro_get {
    my ($count, $urls) = @_;
    my $data;
    my @coros;
    my $semaphore= Coro::Semaphore->new(1);
    my $ua  = FurlX::Coro->new();
    for (1 .. $count) {
        my $url = $urls->[int(rand($#{$urls}+1))];
        push @coros, async {
            my $guard = $semaphore->guard;
            my $res = $ua->get($url);
            $data->{'code'}->{$res->code}++;
        };
    }
    $_->join for @coros;
    return $data;
}
{% endhighlight %}

然后贴的是用async_pool的代码，从perldoc来看据说是比async还快一倍。
{% highlight perl %}
sub coro_pool_get {
    my ($count, $urls) = @_;
    my $sem = Coro::Semaphore->new( 1 - $Coro::POOL_SIZE );
    my $ua = new FurlX::Coro;
    my $data;
    for( 1 .. $count ){
        my $url = $urls->[int(rand($#{$urls}+1))];
        async_pool { my $res = $ua->get("$url"); $data->{'code'}->{$res->status}++; $sem->up; }; 
    };
    $sem->down;
    return $data;
};
{% endhighlight %}

在两个函数中，只要修改$semaphore或者$limit的构造参数，就可以获得并发ESTABLISHED的效果。同样是4核nginx，基本在设置init var为100的情况下，最后整个脚本带来的是3000+的ESTABLISHED，然后可能出现少量的非200响应。

