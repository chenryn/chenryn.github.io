---
layout: post
theme:
  name: twitter
title: php编译参数问题一例
date: 2011-03-31
category: php
---

某php应用在给图片加水印的时候，显示的中文全都成了乱码，而开发同事在它本机(ubuntu)上apt安装的lamp上显示没有问题。仔细检查过了从env到encoding到phpinfo，都没有发现问题——都符合GD函数imagettftext()的utf8要求。
还好有google，发现一个类似的文章，提出是php的编译参数中有一个--enable-gd-jis-conv，会把ttf字库中非标准拉丁文的部分，按照日文顺序映射，imagettftext()的默认编码其实被隐形指定成了日文编码euc-jp，中文自然就不正常了！
然后赶紧重新看phpinfo，真有这个参数。重新编译php，随后恢复正常显示了。
编译参数还真是不能大意啊～～
