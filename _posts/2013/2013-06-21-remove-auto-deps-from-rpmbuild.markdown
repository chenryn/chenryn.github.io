---
layout: post
title: 如何去除 rpmbuild 自动发现的依赖关系
category: linux
tags:
  - perl
  - bash
---

同事在用简单的 SPEC 配置打包 nagios 套件的时候，发现最后生成的 RPM 包附加了很多依赖关系。其中 `perl-Net-SNMP` 这个包，是服务器默认安装中没有的。这也不是什么大问题。不过这个出现还是蛮奇怪的。值得研究一下。

后来在 `/usr/lib/rpm/` 目录下发现了一系列脚本，诸如`javadeps`/`perl.req`/`pythondeps`/`find-requires`/`mono-find-requires`等等。

这些脚本的作用是，用 `file` 命令判断文件，如果是二进制的，用ldd判断依赖；如果是脚本，过滤文件中对应的 `use`/`requires`/`import` 语句。这样就可以找出来源代码的内部依赖了。

那么怎么才能跳过这段逻辑呢？

最暴力的办法，这些文件都是 bash 或者 perl 脚本，直接修改。

但是还可以文明一点，像下面这段，添加在 SPEC 文件中：

```bash
    %setup
    
    %prep
    cat << \EOF > %{name}-req
    #!/bin/sh
    %{__perl_requires} $* |\
    sed -e '/perl(Net::SNMP)/d'
    EOF
    %define __perl_requires %{_builddir}/%{name}-%{version}/%{name}-req
    chmod 755 %{__perl_requires}
```

这里重定义了一个脚本，原先的定义在 `/usr/lib/rpm/macros` 中，是：

```bash
    #%__find_provides       /usr/lib/rpm/rpmdeps --provides
    #%__find_requires       /usr/lib/rpm/rpmdeps --requires
    %__find_provides        /usr/lib/rpm/find-provides
    %__find_requires        /usr/lib/rpm/find-requires
    #%__perl_provides       /usr/lib/rpm/perldeps.pl --provides
    #%__perl_requires       /usr/lib/rpm/perldeps.pl --requires
    %__perl_provides        /usr/lib/rpm/perl.prov
    %__perl_requires        /usr/lib/rpm/perl.req
    %__python_provides      /usr/lib/rpm/pythondeps.sh --provides
    %__python_requires      /usr/lib/rpm/pythondeps.sh --requires
    %__mono_provides        /usr/lib/rpm/mono-find-provides %{_builddir}/%{?buildsubdir} %{buildroot} %{_libdir}
    %__mono_requires        /usr/lib/rpm/mono-find-requires %{_builddir}/%{?buildsubdir} %{buildroot} %{_libdir}
```

然后将加入了 `sed` 命令的新脚本定位为新的 MACROS 变量给 `rpmbuild` 后续使用。

