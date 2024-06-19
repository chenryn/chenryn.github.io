---
layout: post
theme:
  name: twitter
title: perl小测试题(转自CU)
date: 2011-07-21
category: perl
---

原贴地址：http://bbs.chinaunix.net/thread-3563215-1-1.html
flw回帖里有翻译，我试答如下：
1. Perl 5 中变量名开头的那个字符（sigils）有哪几种、分别都有什么含义？
$标量@数组%散列&函数
2. 访问一个数组元素时，用 $items[$index] 和用 @items[$index] 有什么区别？
$是标量，@是数组切片
3. 请问 == 和 eq 之间的区别是什么？
分别是数值和字符的比较
4. 在列表上下文中对一个 hash 求值，会得到什么？
应该是得到一个数组？
5. 如何查看关键字的 Perl 文档？
perldoc -f 
6. Perl 5 中的函数和方法有什么不同？
方法是bless后的函数调用？
7. Perl 5 什么时候对一个变量所使用的内存进行回收？
引用计数器清空后？（好像记得是）或者执行完成退出的时候
8. 如何做才能够确保一个变量的缺省作用域是词法作用域？
my local？
9. 如何加载模块并且从中导入符号？
use Module;
符号是啥？
10. 是什么在控制 Perl 如何加载模块？有什么办法可以指定一个目录清单告诉 Perl 从这些地方尝试加载模块？
不知道。
use lib qw();或者perl -I或者export PERL5LIB=
11. 你怎么在 Perl 5 的文档中中查看一条错误信息说明？（加分项：了解如何为所有遇到过的错误信息启用解释）
汗，这个用|less然后/搜索……有好办法么？
12. 试着阐述一下把数组传递给函数的时候会发生什么事。
应该是复制一个数组副本出来，然后赋值到@_给函数用？
13. 如何传递多个独立的数组给函数？
分别传递数组引用。
14. 对于调用方来说，return 和 return undef 有什么区别？
return的应该是上一个的结果吧？
15. Where do tests go in a standard CPAN distribution?
module里头都有t/目录可以test吧，然后cpan.org上有志愿者？
16. 拿到一个 CPAN 模块后怎样进行测试？
make test
17. 你用什么命令从 CPAN 上安装新模块？
cpanm Module
18. 为什么要使用 open 函数的三参数形式？
预防文件名带有>等特殊字符串
19. 如何检测（和报告）像 open 这样的系统调用产生的错误？（加分项: 知道如何开启自动检测和报告）
在open的时候接上or die $@；
use autodie;
20. 如何在 Perl 5 中抛出一个异常？
die
21. 如何在 Perl 5 中捕获一个异常？
eval {}
22. 用 for 读文件和用 while 读文件有什么不同吗？
for一次性读入；while一次一行
23. 在 Perl 5 的函数或者方法中，你分别是如何处理参数的？
my $abc = shift;
my ($abc, $def) = @_;
24. my ($value) = @_; 中的小括号有什么用？如果删掉会发生什么？
强制为列表环境；
删掉之后变成标量环境就是@_的元素个数了。
25. new 是 Perl 5 的内置函数或者关键字吗？
不是，模块里要自己写new方法。
26. 你怎么看 Perl 的核心模块的文档？如果是 CPAN 模块的话又该如何看？
perldoc查看，不过核心模块和一般模块方法有区别么？
27. 怎样只访问 hash 的值？
values函数
