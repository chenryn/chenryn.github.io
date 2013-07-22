---
layout: post
title: Selenium 测试框架介绍
categories:
  - perl
  - monitor
tags:
  - javascript
  - firefox
  - perl
  - automation
---

Selenium 是一个自动化网站测试框架，包括 IDE、WebDriver 和 Grid 三个套件。其官网地址见：<http://docs.seleniumhq.org/projects/>。其中 Grid 用以跨主机的集群测试，今天就不讲了。而 WebDriver 则是用以控制 Selenium Server(Server 上可以接受并启动的浏览器包括Firefox、IE、Chrome、Safari、Android、IPhone、PhantomJS 等等)进行具体测试动作的客户端，其早期版本叫做 Remote Control。

最有特色和帮助的，是 IDE 部分，这是一个 Firefox 的 xpi 插件。通过下载安装，就可以启用，然后就是最简单不过的浏览器操作录制，结束动作后就可以自动导出各种支持的语言版本的 WebDriver 程序。

注意在安装好 xpi 后，在 IDE 上并不能同步看到生成的程序内容，并不是说没有录制，而是默认不显示 `options/format` 的内容。在 `options/options` 里把 `active developer tools` 选项激活就可以了。

Selenium 是一个 java 项目，官方支持的客户端程序包括 Java、C#、Ruby 和 Python2。社区支持的包括 Perl、PHP 和 Haskell 等等。

注意 Selenium 的 WebDriver 和 Remote Control 两个版本之间 API 已经完全不一样，所以在 IDE 录制的时候，format 已经要选 WebDriver API 的才能用——除非你还找得到老版本的 Selenium Server，反正我是没找到。

不巧的是目前官网上的插件列表中，只有官方支持的四个更新了 WebDriver 的 IDE 支持。所以直接从官网上安装的 Perl plugin 其实是没用的。不过不要紧，我很容易就找到了支持 WebDriver 的 Perl 模块，并且还使用 Perl 模块完成了对 Selenium Server 的管理。

这里要用到两个 CPAN 模块：[Selenium::Server](https://metacpan.org/module/Selenium::Server) 和 [Selenium::Remote::Driver](https://metacpan.org/module/Selenium::Remote::Driver)。

由于 Firefox addons 网站上的 [Selenium IDE: Perl Formatter](https://addons.mozilla.org/zh-CN/firefox/addon/selenium-ide-perl-formatter/?src=search) 还是老版本的，即 [Test::WWW::Selenium](https://metacpan.org/module/Test::WWW::Selenium) 配套的，所以我们需要自行安装新版本插件。

新版本插件也就是一段 javascript 代码，在 [Selenium::Remote::Driver](https://metacpan.org/module/Selenium::Remote::Driver) 代码库目录中已经存在，即 <https://github.com/aivaturi/Selenium-Remote-Driver/blob/master/ide-plugin.js>。

按照 js 文件开头注释中的介绍，在 Selenium IDE 的 `options/options` 菜单的 `Formats` 选项卡上点击 `Add` 按钮，给新的 format 取名为 `Perl-WebDriver`，然后把整个 js 文件内容贴进文本框内保存即可。

现在，录制操作只需选择使用 `Perl-WebDriver` 格式，就可以生成 Perl 测试脚本使用了。

下一个问题，就是 Selenium Server 的运行。IDE 生成的脚本只负责连接 server 并发送命令。server 的 状况在 IDE 中是在 `options/formats` 中定义的变量，即 Selenium RC host 、Selenium RC port 和 environment。默认是 `localhost`、`4444` 和 `firefox`。在生成脚本的时候会自动替换。

也就是说，我们需要自己部署程序，再运行一个脚本，启用 java 程序，来运行 Selenium Server。

这里就可以用上 [Selenium::Server](https://metacpan.org/module/Selenium::Server) 了。程序的下载、启用、参数配置和停止，都有该模块完成。

最后一步，我们可以把 [Selenium::Server](https://metacpan.org/module/Selenium::Server) 的相关代码，也贴进 IDE 的 `options/formats` 的 `Header` 和 `Footer` 模板里。这样不用每次自己粘贴了——自己粘贴代码还不如直接自己启用一个固定监听 4444 端口的 java 程序得了。

IDE 截图如下：

![selenium-ide](/images/uploads/selenium-ide.png)

生成脚本如下所示：

{% highlight perl %}
    use strict;
    use warnings;
    use Selenium::Server;
    use Selenium::Remote::Driver;
    use Test::More;
    
    my $server = Selenium::Server->new;
    $server->start;
    
    my $driver = Selenium::Remote::Driver->new(
        remote_server_addr => $server->host,
        port               => $server->port
    );
    
    $driver->get("http://10.2.21.100:8081/?results=88ceefac3c0c588d14f579d0c47f74fc");
    $driver->find_element("DNS可用性测试", "link")->click;
    like(qr/^[\s\S]*各地测试可用性[\s\S]*$/,$driver->find_element("BODY", "css")->get_text);
    $driver->quit();
    done_testing();
    
    $server->stop;
{% endhighlight %}

脚本中这个 `click` 操作显然是直接根据动作录制的，那么 `find_element()->get_text` 是怎么来的呢？其实 Selenium IDE 已经修改了浏览器内鼠标右键菜单的选项。在选中的任意网页元素上单击鼠标右键，菜单中就有 `Show All Available Commands` 子菜单，只需要选择就可以了。方便吧！

生成的脚本直接运行，就可以完成测试了。

和 `Selenium` 类似的，还有 [WWW::WebKit](https://metacpan.org/module/WWW::WebKit) 模块，它是调用 [Gtk3::WebKit](https://metacpan.org/module/Gtk3::WebKit) 作为后端浏览器支持，不过经过我个人电脑测试，要安装好 [Gtk3::WebKit](https://metacpan.org/module/Gtk3::WebKit) 本身就是一件很复杂的事情。加上有时候我们也需要比较不同浏览器的效果是不是有所不同。所以，还是用 Selenium 吧。

注：在最近一期 PerlWeekly 对 Perl 社区创业公司 Lokku/Nestoria 的[访谈](http://blogs.perl.org/user/ovid/2013/07/perl-startups-lokkunestoria.html)中，Lokku 公司 CTO，Alex Balhatchet 也提到准备使用 Selenium 改造公司的自动化测试。

