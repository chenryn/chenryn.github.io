---
layout: post
title: 在 Docker 上运行 PerlDancer 示例
category: cloud
tags:
  - perl
---

搭建好了 docker 环境后，就可以来试试用 docker 跑一个应用实例来看看了。和 Vagrant 比较类似，docker 也是用一个配置文件来规划其基础镜像内的部署，不过值得注意的是，在 `Dockerfile` 里的每一个指令成功执行后，docker 默认都会 commit 一次，这样就节省了一些空间和时间。

构建失败的镜像，在 `docker images` 命令输出中显示为 `<none>` 可以根据具体的 commit id，调用 `docker rmi <id>` 命令清除。

一个比较简单的 `Dockerfile` 示例是这样的：

```ruby
FROM centos:6.4
RUN yum install make gcc wget perl perl-devel perl-Time-HiRes perl-CGI perl-libwww-perl perl-Module-Build perl-Test-Simple perl-Test-Deep perl-YAML
RUN wget http://cpanmin.us
RUN perl cpanm Dancer
ADD /var/www/dancerapp app
EXPOSE 3000
CMD perl app/bin/app.pl
```

然后运行如下命令构建镜像：

    docker build -t chenryn/perldancer

如果构建都成功的话，那就是正式运行了：

    docker run -p 8080:3000 -d chenryn/perldancer

运行起来以后，可以通过 `docker ps` 命令看到本机上运行着的容器状态信息。同样，也可以通过映射的 8080 端口访问到页面了。

正在测试通过 `plenv` 来使用高版本的 perl，目前比较郁闷的是因为 `plenv` 是通过 `~/.profile` 来在每次登陆的时候自动切换到指定版本的，而 `docker` 里的 `RUN` 调用 `/bin/sh -c` 不会调用到这些文件，所以一直还是使用系统自带版本。而在 `RUN` 指令里每行都写一个 `source $HOME/.profile` 也很难看的。

