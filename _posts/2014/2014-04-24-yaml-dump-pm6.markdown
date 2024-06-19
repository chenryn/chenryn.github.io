---
layout: post
theme:
  name: twitter
title: Perl6 的 YAML::Dumper 模块
category: perl
tags:
  - rakudo
  - moarvm
  - perl6
  - yaml
  - sqlite
---

这两天决定试一把 Perl6，因为[扶凯](http://www.php-oa.com)兄已经把还没有正式发行 Rakudo Star 包的 MoarVM 编译打包好了，所以可以跳过这步直接进入模块安装。当然，源码编译本身也没有太大难度，只不过从 github 下源码本身耗时间比较久而已。

既然木有 Star 包，那么安装好 MoarVM 上的 Rakudo 后我们就有必要先自己把 panda 之类的工具编译出来。这一步需要注意一下你的 `@*INC` 路径和实际的 `$PERL6LIB` 路径，已经编译之后的 panda 存在的 `$PATH` 是不是都正确，如果不对的修改一下 `~/.bashrc` 就好了。

我的尝试迁移对象是一个很简单的 Puppet 的 ENC 脚本，只涉及 SQLite 的读取，以及 YAML 格式的输出。通过 `panda install DBIish` 命令即可安装好 DBIish 模块。

脚本本身修改起来难度不大，结果如下：

```perl
#!/usr/bin/env perl6
use v6;
use DBIish;
use YAML;
my $base_dir = "/etc/puppet/webui";
# 函数在 Perl6 中依然使用 sub 关键字定义，不过有个超酷的特性是 multi sub
# 脚本中没有用到，但是在 YAML::Dumper 中遍地都是，这里也提一句。
# MAIN 函数在 Perl6 里可以直接用 :$opt 命令参数起 getopt 的作用
# 不过 ENC 脚本就是直接传一个主机名，用不上这个超酷的特性
sub MAIN($node) {
# connect 方法接收参数选项是 |%opts，所以可以把哈希直接平铺写
# 这个 | 的用法一个月前在《Using Perl6》里看到过
    my $dbh = DBIish.connect( 'SQLite', database => "{$base_dir}/node_info.db" );
    my $sth = $dbh.prepare("select * from node_info where node_fqdn = ?");
    $sth.execute("$node");
    my $ret = $sth.fetchrow_hashref;
    my $res;
    if ( !$ret ) {
        $res = {
# Perl5 的 qw() 在 Perl6 里直接写成 <> 。也不用再通过 [] 来指明是引用
            classes     => <puppetd repos>,
            environment => 'testing',
        };
    }
    else {
        $res = {
            environment => $ret{'environment'},
            parameters  => { role => $ret{'role'} },
            classes     => {},
        };
# 这个 for 的用法，在 Perl5 的 Text::Xslate 模板里就用过
        for split(',', $ret{'classes'}) -> $class {
            if ( $class eq 'nginx' ) {
# 这个 <== 符号指明数据流方向，完全可以把数组倒过来，然后用 ==> 写这行
# 如果不习惯这种流向操作符的，可以用,号，反正不能跟 Perl5 那样啥都不写
# 这里比较怪的一点是我试图把这么长的一句分成多行写，包括每行后面加\，我看到 YAML 代码里就用\分行了，但是我这就会报错
# Perl6 的正则变化较大，这里 /^#/ 要写成 /^'#'/ 或者 /^\x23/
# 正则 // 前面不加 m// 不会立刻开始匹配
# 原先的 s///g 可以写作 s:g///，也可以写作对象式的 .subst(m//, '', :g)，. 前面为空就是默认的 $_
# 捕获的数据存在 @() 数组里，也可以用 $/[i] 的形式获取
# 字符串内插时，不再写作 ${*}，而是 {$*} 的形式
# 命名捕获这里没用上，写个示例：
#     $str ~~ /^(\w+?)$<laststr>=(\w ** 4)\w$/;
#     $/<laststr>.chomp.say;
# 注意里面的 \w{4} 变成了 \w ** 4
                my @needs <== map { .subst(m/^(.+)\:(\d+)$/, "{$/[0]} max_fails=30 weight={$/[1]}", :g) } <== grep { !m/^\x23/ } <== split(',', $ret{'extstr'});
                $res{'classes'}{'nginx'}{'iplist'} = @needs;
            }
            else {
# Perl5 的 undef 不再使用，可以使用 Nil 或者 Any 对象
                $res{'classes'}{$class} = Nil;
            }
        }
    };
    $dbh.disconnect();
# 这个 dump 就是 YAML 模块导出的函数
# Perl6 的模块要导出函数不再需要 Exporter 那样，直接用 our sub dump($obj) {} 就可以了
    say dump($res);
};
```

但是麻烦的是 YAML 模块本身，这个模块是 ingydotnet 在好几年前草就，后来就没管了，实际现在压根跑不起来。花了半天时间，一边学习一边修改，总算修改正常了。主要涉及了 `Attribute` 对象，`Nil` 对象，`twigls` 前缀符，`:exists` 定义几个概念，以及 YAML 格式本身的处理逻辑。

YAML 模块修改对比如下：

    diff --git a/lib/YAML/Dumper.pm b/lib/YAML/Dumper.pm
    index d7a7981..ec47341 100644
    --- a/lib/YAML/Dumper.pm
    +++ b/lib/YAML/Dumper.pm
    @@ -2,16 +2,16 @@ use v6;
     class YAML::Dumper;
     
     has $.out = [];
    -has $.seen is rw = {};
    +has $.seen = {};
     has $.tags = {};
     has $.anchors = {};
     has $.level is rw = 0;
    -has $.id is rw = 1;
    +has $.id = 1;
     has $.info = [];
     
     method dump($object) {
         $.prewalk($object);
    -    $.seen = {};
    +    $!seen = {};
         $.dump_document($object);
         return $.out.join('');
     }
    @@ -45,11 +45,11 @@ method dump_collection($node, $kind, $function) {
     
     method check_special($node) {
         my $first = 1;
    -    if $.anchors.exists($node.WHICH) {
    -    if $.anchors.exists($node.WHICH) {
    +    if $.anchors{$node.WHICH}:exists {
             push $.out, ' ', '&' ~ $.anchors{$node.WHICH};
             $first = 0;
         }
    -    if $.tags.exists($node.WHICH) {
    +    if $.tags{$node.WHICH}:exists {
             push $.out, ' ', '!' ~ $.tags{$node.WHICH};
             $first = 0;
         }
    @@ -64,7 +64,7 @@ method indent($first) {
                 return;
             }
             if $.info[*-1]<kind> eq 'seq' && $.info[*-2]<kind> eq 'map' {
    -            $seq_in_map = 1;
    +            $seq_in_map = 0;
             }
         }
         push $.out, "\n";
    @@ -155,7 +155,8 @@ method dump_object($node, $type) {
         $.tags{$repr.WHICH} = $type;
         for $node.^attributes -> $a {
             my $name = $a.name.substr(2);
    -        my $value = pir::getattribute__PPs($node, $a.name);     #RAKUDO
    +        #my $value = pir::getattribute__PPs($node, $a.name);     #RAKUDO
    +        my $value = $a.get_value($node);                         #for non-parrot
             $repr{$name} = $value;
         }
         $.dump_node($repr);

这里的 `$.seen` 和 `$!seen` 是不是晕掉了？其实 `$.seen` 就相当于先声明了 `$!seen` 后再自动创建一个 `method seen() { return $!seen }`。

另一处是 `pir::getattribute__PPs()` 函数，pir 是 parrot 上的语言，而 MoarVM 和 JVM 上都是先实现了一个 nqp 再用 nqp 写 Perl6，不巧的是这个 pir 里的 `getattribute__PPs()` 刚好至今还没有对应的 nqp 方法。(在 pir2nqp.todo 文件里可见)

所以只能用高级的 Perl6 语言来做了。

总的来说，这个 yaml-pm6 代码里很多地方都是试来试去，同样的效果不同的写法，又比如 `.WHICH` 和 `.WHAT.perl` 也是混用。
而且我随手测试了一下，即使在 parrot 上，用 `pir::getattribute__PPs` 的速度也比 `Attribute.get_value` 还差点点。

------------------------

最后提一句，目前 ENC 脚本在 perl5、perl6-m、perl6-p、perl6-j 上的运行时间大概分别是 0.13、1.5、2.8、12s。MoarVM 还差 Perl5 十倍，领先 parrot 一倍。不过 JVM 本身启动时间很长，这里不好因为一个短时间脚本说它太慢。

另外还试了一下如果把我修改过的 YAML::Dumper 类直接写在脚本里运行，也就是不编译成 moarvm 模块，时间大概是 2.5s，比 parrot 模块还快点点。

不过如何把 perl6 脚本本身编译成 moarvm 的 bytecode 格式运行还没有研究出来，直接 `perl6-m --target=mbc --output=name.moarvm name.pl6` 得到的文件运行 `moar name.moarvm` 的结果运行会内存报错。
