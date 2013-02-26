---
layout: post
title: Perl5里的gather/take
category: perl
---
九月末的YAPC::Asia上，Larry Wall展示了一下怎么把一个perl5上很标准的排序脚本改造成perl6脚本。主要是条件语句不再用()了，子函数传参方式，对象化操作等等。唯独有个命令是之前未见过的：gather/take。用这个可以减少临时变量的使用。

找了一下，类似命令在perl5中有多个模块对应：[Perl6::GatherTake](http://search.cpan.org/~moritz/Perl6-GatherTake-0.0.3/lib/Perl6/GatherTake.pm)、[Perl6::Take](http://search.cpan.org/~gaal/Perl6-Take-0.04/lib/Perl6/Take.pm)、[Perl6::Gather](http://search.cpan.org/~dconway/Perl6-Gather-0.42/lib/Perl6/Gather.pm)、[List::Gather](http://search.cpan.org/~flora/List-Gather-0.06/lib/List/Gather.pm)和[Syntax::Keyword::Gather](http://search.cpan.org/~frew/Syntax-Keyword-Gather-1.002000/lib/Syntax/Keyword/Gather.pm)。

具体的说明，可以看[Perl6::Gather](http://search.cpan.org/~dconway/Perl6-Gather-0.42/lib/Perl6/Gather.pm)的POD说明，比较详细。其他的都是简单给个例子就是了。

{% highlight perl %}
use Perl6::Gather;
print gather {
    for (@data) {
        take if $_ % 2;
        take to_num($_) if /(?:one|three|five|nine)\z/;
    }
    take 1,3,5,7,9 unless gathered;
}
{% endhighlight %}

相当于：

{% highlight perl %}
my @arrays;
for (@data) {
    push @arrays, $_ if $_ % 2;
    push @arrays, to_num($_) if /(?:one|three|five|nine)\z/;
}
@arrays = (1,3,5,7,9) unless @arrays;
print @arrays;
{% endhighlight %}

省略的就是这个push用的临时@arrays变量。同样也可以是标量，用~gather就可以省略.=了，比gather前面多一个波浪号~。

