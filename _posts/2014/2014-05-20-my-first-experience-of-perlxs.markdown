---
layout: post
title: XS 初体验
category: perl
tags:
  - c
  - xs
  - perl
---

今天翻 ganglia 源代码发现两年前加上了 `perl_module` 的[支持](http://t.cn/Rvwav9T)，不过跟 `python_module` 相比，`descriptors` 里的 `call_back` 不是真的写作回调函数而是写作和实际函数同名的字符串，这点让我觉得很别扭和奇怪，于是想到去看看 gmond 里内嵌的 perl 解释程序是怎么做这步的。顺带就第一次动手写了一点 XS 代码，这里一并发上来，留作存档。

示例代码框架源自上周 Dancer 作者 SawyerX 发布的 [XS-Fun 项目](https://github.com/xsawyerx/xs-fun)。所以这里如何使用 `h2xs` 命令创建 XS 模块文件就不讲解了。

主要分作五个小示例，由最简单到很简单依次如下：

返回一个字符串
======================

编辑 XSFun.xs 内容如下：

{% highlight c %}
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/* C functions */

MODULE = XSFun		PACKAGE = XSFun		

# XS code

SV *
runcb()
    CODE:
        STRLEN len;
        const char* str = "testsub";
        SV* val = newSVpv(str, len);
        RETVAL = val;
    OUTPUT: RETVAL
{% endhighlight %}

这个其实就相当于 `sub runcb { return "testsub" }` 。

返回一个哈希的指定键的值
==========================

因为起因是 gmond 里的代码，所以这里就开始主要研究如何解析 descriptor 哈希的键值对了。下面是 `runcb()` 的代码片段：

{% highlight c %}
SV *
runcb(SV *sref)
    CODE:
        HV* plhash = (HV*)(SvRV(sref));

        const char* key = "call_back";
        SV* val = *hv_fetch(plhash, key, strlen(key), 0);
        RETVAL = val;
    OUTPUT: RETVAL
{% endhighlight %}

这里两个要点，一个是传递进来的哈希引用如何解引用(perl程序里任何时候都不应该直接传递哈希或者数组，而应该传递引用，所以这里直接就研究这步了)；一个是 `hv_fetch` 的返回值是 `SV**` 而不是 `SV*`。

发现 XS 语法里比较有意思的一点，就是变量类型转换的时候，大小写的意义。像 `SvRV` 就是从 SV 变成 RV，而 `SViv` 就是从 IV 变成 SV，基本是谁大写就是转变成谁。

调用 Perl 函数并获取其返回值
=============================

刚才说到了 descriptor 里的 "call_back" 键的值其实是函数名，所以这一步就试图运行这个 Perl 函数。

{% highlight c %}
SV *
runcb(SV *sref)
    CODE:
        HV* plhash = (HV*)(SvRV(sref));
        const char* key = "call_back";
        SV* cb = *hv_fetch(plhash, key, strlen(key), 0);
        int count = call_sv(cb, G_SCALAR);
        RETVAL = POPs;
    OUTPUT: RETVAL
{% endhighlight %}

这里的要点：

* `call_sv` 函数(传递的是函数引用)。在 gmond 源码里用的是 `call_pv` 函数(传递的是函数名字符串)。可见原来在代码层这里写起来几乎是一样的，看来定义成写字符串纯粹是作者个人偏好了。

* 这里要给被调用的函数设定上下文，我这里要求返回字符串，就是 `G_SCALAR`，还有 `G_VOID` 等等，详见 [perlcall文档](perldoc.perl.org/perlcall.html)。

* POPs 操作。`call_sv` 函数返回值只代表**被**调用的函数的返回值个数，**被**调用函数的返回值本身，需要另外*逐一*获取，这个获取就是通过 POPs( 这个是取SV，类似的还有 POPi 等)来完成。

给被调用的 Perl 函数传参
==========================

在上面我们可以看到 `call_sv` 函数也没有传递参数的地方。那么怎么传递参数给被调用的 Perl 函数呢？

{% highlight c %}
SV *
runcb(SV *sref, SV *argv)
    CODE:
        HV* plhash = (HV*)(SvRV(sref));
        const char* key = "callback";
        SV* cb = *hv_fetch(plhash, key, strlen(key), 0);
        STRLEN len;
        PUSHMARK(SP);
        XPUSHs(sv_2mortal(argv));
        PUTBACK;
        int ret = call_sv(cb, G_SCALAR);
        SPAGAIN;
        if (ret != 1) {
            croak("error");
        };
        SV* s = POPs;
        printf("Here: %d %s\n", ret, SvPV(s, len));
        RETVAL = s;
        PUTBACK;
    OUTPUT: RETVAL
{% endhighlight %}

比较复杂啦~~

这里需要有一系列处理 Perl 堆栈的命令来完成传参处理，命令以 `dSP` 开头，不过如果编写的是 XS 函数，这步会自动处理可以省略，所以我们这里只需要从 `PUSHMARK` 开始。

以 `PUSHMARK` 标示开始推入参数到临时区域，然后具体的推入命令是 `XPUSHs`(多个就重复推)，最后以 `PUTBACK` 标示参数推入完成。这时候 Perl 解释器就明白，给下面的 sub 准备的 `@_` 已经完毕了，具体大小就是这么多不会再多了。

`SPAGAIN` 的作用是清理临时区域，因为说不准被调用函数里对临时区域做了什么操作。

同样是 POPs 取出，这里如果直接在 C 代码里 printf 的话，要注意把 SV 转换成 PV，否则是看不对的。

遍历哈希和返回数组
=====================

前面都是单个变量操作，最后我们来试试哈希遍历，然后返回数组变量。

{% highlight c %}
AV *
runcb(SV *href)
    CODE:
        HV* plhash = (HV*)(SvRV(href));
        char *key;
        SV* sv_value;
        I32 ret;
        RETVAL = newAV();
 
        hv_iterinit(plhash);
        while ((sv_value = hv_iternextsv(plhash, &key, &ret))) {
            av_push(RETVAL, sv_value);
        }
    OUTPUT: RETVAL
{% endhighlight %}

这里几个要点：

* `runcb()` 函数的返回类型要改成 `AV*` 了。
* `RETVAL` 需要单独声明赋值才行。

写到这里我顺带想到，虽然 Perl5 一直都不对函数传参做什么验证，但是其实 XS 是 C 的自定义语言，所以写 XS 的时候，传参是会自动验证的。Perl5 二十年轮回，今年终于把传参验证给加上了，只能说一代人有一代人的想法啊。。。

