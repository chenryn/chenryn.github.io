---
layout: post
title: 通过网页运行 Perl 代码的安全实现
category: perl
tags:
  - perl
  - docker
  - javascript
---

这几天折腾[Perl中国用户组网站](http://www.perl-china.com)，觉得类似 Ruby 的 tryruby，Scala 的 scala-tour 这样的新手入门教程非常好玩。于是准备自己也尝试一下。

理论上，通过 Ajax 传递代码到服务器上，直接 `eval {}` 即可。不过这样会导致一个安全问题。如何防止用户执行错误代码导致严重后果呢？

我想到了最近一直在跟踪看的 Docker 容器。如果我们把代码放在 Docker 里运行，不就不怕了么。

首先要构建一个可以运行大多数示例代码的 Docker 镜像。

### 首先打开一个终端运行初始镜像：

```bash
# docker run -i -t ubuntu /bin/sh
# apt-get install -y wget gcc make
# useradd tour
# echo 'tour hard nproc 8' >> /etc/security/limits.conf
# wget http://cpanmin.us -O bin/cpanm
# cpanm List::AllUtils Moo Path::Tiny DBD::SQLite AnyEvent::HTTP DateTime
```

### 然后打开另一个终端保存前一个终端的变更：

```bash
# docker ps
CONTAINER ID ...
# docker commit <ID> perl-tour
```

注意一定要在之前 `cpanm` 已经成功执行完毕后保存，但是前面登录进 docker 的会话千万不要退出，否则后面的 `docker ps` 就查看不到 id 了。退出时这些临时变更都毁掉了。

__2014 年 1 月 7 日补充__

被莫莫用死循环 `fork()` 轰炸了一回，发现 docker 容器的一个问题，容器技术本身没有对用户最大进程数的限制。因为其实际运行的是 `docker -d` 服务进程的子进程。

直接在镜像里编辑 `/etc/security/limits.conf` 实测没有作用。而主机上限定普通用户的 nproc 也没用(因为普通用户运行不了 docker )。

最后想到的办法，是启动 `docker -d` 的时候，先 `ulimit -HSu 16`，这样这个 docker 下一共也跑不了多少 fork 了。

顺带提一句，查阅系统日志可以发现，在 fork 的时候，其实触发了主机的 OOM-killer，但是这个机制在死循环这个变态攻击下挽救不了主机……

__END__

现在我们已经有了一个安装好很多常用 CPAN 模块的镜像了。可以取构建网站了。

网站里添加下面一段：

```perl
use Dancer::Plugin::Ajax;
use File::Temp qw(tempfile);
use IPC::Run qw(start harness timeout);
ajax '/run' => sub {
    my $code = param('code');
    my @cmd = qw(docker run -m 128m -u tour -v /tmp/:/tmp:ro perl-tour perl);
    my ($fh, $temp) = tempfile();
    binmode($fh, ':utf8');
    print $fh $code;
    push @cmd, $temp;
    my $h;
    eval {
        $h = harness \@cmd, \$in, \$out, \$err, timeout(5);
        start $h;
        $h->finish;
    };
    if($@) {
        my $x = $@;
        $h->kill_kill;
        return $x;
    };
    unlink $temp;
    return to_json({
        Errors => [ split(/\n/, $err) ],
        Events => [ split(/\n/, $out) ],
    });
};
```

页面上通过 Ajax 请求交互：

```javascript
  $.ajax("/run?code=" + encodeURIComponent(codeStr), {
    type: "GET",
    dataType: "json",
    success: function(data) {
      if (!data) {
        return;
      }
      if (data.Errors && data.Errors.length > 0) {
        setOutput(outputDiv, null, null, data.Errors);
        return;
      }
      setOutput(outputDiv, data.Events, data.ErrEvents, false);
    },
    error: function() {
      outputDiv.addClass("error").text(
        "Error communicating with remote server.");
    }
  });
```

静态页面部分严重参考了 Scala 的 Tour 页。趁机学习了 impress.js 制作幻灯片效果、codemirror 实现代码高亮效果。

最终效果见 [少年 Perl 的魔法世界](http://www.perl-china.com/tour.html)。欢迎大家莅临指导~

最后，阅读了 Golang Tour 关于 [Go Playground](http://play.golang.org) 的原理说明，发现它们是在 Google App Engine 上运行实例，然后走消息队列把代码发送给后台实例运行结果。

当然，Go Playground 不单单是支持 Tour，而且还包括社区各式第三方模块的测试和使用。把角色拆分出来也是正常的。
