---
layout: post
title: 分布式shell程序
date: 2009-11-04
category: linux
---

除了用expect+for循环以外，今天偶然看到分布式shell这个概念。随手百度一些资料，放到这里，等过段时间试试~~

[DSH——dancer's shell / distributed shell](http://www.netfort.gr.jp/~dancer/software/dsh.html.en)

开发者是在debian/ubuntu上做的，依赖libdshconfig，如果要部署在其他linux发行版上，还得好好编译一番。
[pssh](http://www.theether.org/pssh/) ——这个系列很全，ssh/scp/rsync/nuke/slurp都有。
这个默认下载是rpm包。
[cssh](http://sourceforge.net/apps/mediawiki/clusterssh/index.php?title=Main_Page)
这个是用perl编写的，感觉普通使用的时候就像是SecureCRT、XShell这些windows平台上的ssh工具一样标签组管理登陆，但多了一个向组服务器同时发送命令的功能。
还有更多工具，见下：
<a href="http://www.gentoo.org/news/zh_cn/gmn/20080930-newsletter.xml">http://www.gentoo.org/news/zh_cn/gmn/20080930-newsletter.xml</a>

