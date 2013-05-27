---
layout: post
title: 使用 Rex::Box 代替 Vagrant 的工作
category: devops
tags:
  - rex
  - perl
  - virtualbox
---

Vagrant 是近来 devops 界内非常流行和火爆的工具，它和 puppet/chef 的结合，成为运维开发和测试，甚至预热部署的重要手段。比如在 cloudfoundry 官方放弃使用 `vcap_setup` 脚本部署后，社区大多对其 `BOSH` 不买账，转而研究使用 vagrant 部署了。

对于 perl 运维人员，使用 Rex 工具做集群管理的话，其实完全不用再使用 vagrant 了。因为 Rex 自带有 Box 功能。完全可以一体化工作。下面从 Rex 官网上半翻译半截取两篇文章，展示 Rex::Box 的使用。两篇原文分别是：

1. <http://box.rexify.org/guide>
2. <http://www.rexify.org/howtos/use_boxes_with_any_box_provider.html>

环境准备
================

{% highlight bash %}
rexify $project-name --template box
cd $project-name
rex init --name=$vm-name --url=$url-to-prebuild-vm-image
{% endhighlight %}

虚拟机定义
================

这里有两种方式，一种是类似 Vagrantfile 定义的 Rexfile 写法：

{% highlight perl %}
set box => "VBox";
task mytask => sub {
   box {
      my ($box) = @_;
      $box->name("boxname");
      $box->url("http://box.rexify.org/box/base-image.box");
      $box->network(1 => {
        type => "bridged"      # 默认是 "nat",
        bridge => "eth0",
      });
      $box->forward_port(ssh => [2222, 22]);
      $box->share_folder(boxhome => "/path/to/myuser");
      $box->auth(
        user => "root",
        password => "box",
      );
      $box->setup(qw/setup_frontend/);
   };
};
{% endhighlight %}

另一种是采用 YAML 配置：

{% highlight yaml %}
type: VBox
vms:
   fe01:
      url: http://box.rexify.org/box/ubuntu-server-12.10-amd64.ova
      network:
         1:
            type: bridged
            bridge: eth0
      setup: setup_frontend
   db01:
      url: http://box.rexify.org/box/ubuntu-server-12.10-amd64.ova
      network:
         1:
            type: bridged
            bridge: eth0
      setup: setup_db
{% endhighlight %}

虚拟机初始化
================

在 Vagrant 中有一个概念叫 provision，也就是在虚拟机第一次运行时，通过 shell/puppet/chef 等进行初始化操作。Rex::Box 自然是通过 Rex 本身来进行这个任务。也就是上例中的 `setup` 定义的 task 名称。

{% highlight perl %}
task 'setup_frontend', sub {
    install nginx;
    file '/etc/nginx.conf',
        content   => template('template/httpd.conf.tpl'),
        owner     => "root",
        group     => "root",
        on_change => sub { service nginx => "restart"; };
};
{% endhighlight %}

因为 rex 本身是通过 ssh 管理，所以在 setup 之前，必须定义好如何 auth，自己做的镜像不说了，通过 rexify.org 下载的默认镜像，就是默认的 root/box 了。

说到镜像，其实 vagrant 的 `.box` 也就是 `.ova` ，都是把 virtualbox 的 `.vmdk` 和 `.ovf` 打了个包而已。

当然，也可以在 task 写 shell，通过 `run` 的方式，其实 run 应该也是 Rex 最常用的 task 了。

{% highlight perl %}
task 'setup_frontend', sub {
    run "echo Hello, world";
};
{% endhighlight %}

虚拟机使用
================

定义完成后，就可以使用 init 配置虚拟机环境，然后 start/stop 管理虚拟机。

比如在使用 YAML 配置的时候，配置环境的 Rexfile 最后是这样的：

{% highlight perl %}
use Rex::Commands::Box init_file => "box.yml";
group myboxes => map { get_box($_->{name})->{ip} } list_boxes;
task "box", sub {
   boxes "init";
};
{% endhighlight %}

像要做成命令行管理也比较简单，比如启动和停止虚拟机的 task 这样写：

{% highlight perl %}
task "stop", sub {
    my $param = shift;
    boxes stop => $param->{name};
};
{% endhighlight %}

就可以在命令行直接这样启动某个虚拟机了：

{% highlight bash %}
rex stop --name=myvbox
{% endhighlight %}

事实上，本文最开头的默认 box 模板生成的命令，就是通过前一步生成的 Rexfile 里定义的 `task "init", sub {...};` 实现的。
