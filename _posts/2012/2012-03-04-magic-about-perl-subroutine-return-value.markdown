---
layout: post
theme:
  name: twitter
title: perl函数返回值引起的误会
date: 2012-03-04
category: perl
---

在微博上偶然看到有位[@南唐古韵](http://weibo.com/iheartbeat "南唐古韵")童鞋发了一条关于perl的：

    发现perl的一个bug：（2**3）**2=8

显然perl不可能真的犯这么白痴的错误，那么问题在哪呢？我们先看看下面这个判断：
```perl
[root@localhost ~]# perl -e 'print "OK" if (2**3)**2 == 8'
[root@localhost ~]# perl -e 'print "OK" if (2**3)**2 == 64'
OK
[root@localhost ~]#
```
一目了然，运算肯定是正确的。那上面那位童鞋的话是怎么得出来的呢？稍微想想，猜他可能是这样：
```perl
[root@localhost ~]# perl -e 'print (2**3)**2'
8
```
哇，真的变成8啦？！

其实都是因为print搞的鬼啦~print作为内置的命令，我们在书写的时候经常用空格分隔开参数，而不记得其实标准的应该用中括号括起来的~
也就是说，其实上面那行命令应该是：
```perl
[root@localhost ~]# perl -e 'print(2**3) **2'
```

然后下一个问题：在print之后还有一个**2啊，既然前面已经执行完成一个print命令，后面再加个东西，咋不会报错呢？

这就是涉及到关键了，perl的print执行也是有返回值的，真为1，假为0。也就是说，上面的命令其实是先执行了2的3次方得到8，然后执行print输出"8"到STDOUT并且返回1；然后执行1的2次方得到1；程序结束。

我们可以这样验证一下：
```perl
[root@AY110907102215177d47d ~]# perl -e 'print (2**3)**2'
8[root@AY110907102215177d47d ~]# perl -e '$r=print (2**3)**2;print $r'
81[root@AY110907102215177d47d ~]# perl -e '$r=print (2**3)*2;print $r'
82[root@AY110907102215177d47d ~]# perl -e '$r=print (2**3)*2,"\n";print $r'
82[root@AY110907102215177d47d ~]# perl -e '$r=print (2**3,"\n")*2;print $r'
8
2[root@AY110907102215177d47d ~]# 
```
因为要给print造一个返回值为假的示例不太容易，所以举一个1\*2=2/0\*2=0来证明咯~至于加上的"\n"测试，更进一步证明它跟print无关啦~~

