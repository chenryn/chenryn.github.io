---
layout: post
title: selinux 对 webserver 文件发布的影响
category: linux
tags:
  - apache
  - selinux
---

SELinux 在国内是一个很少有人用的东西，一般来说，服务器上手第一件事情就是把 SELinux 关掉，以至于有问题的时候排查思路里都压根没检查 SELinux 这步。

昨天在个人电脑的 Fedora 上搭建一个 webserver 发布几个文件，本来想着简单任务越快越好，几行命令完成：

```bash
sudo yum install httpd
sudo mv ~/src /var/www/html/
sudo service httpd start
```

结果居然一直返回 `403 Denied`！

看 httpd 的 error.log ，一直报这么一行错误：

    [core:error] [pid 3806] (13)Permission denied: [client 127.0.0.1:59180] AH00035: access to /src/master.zip denied (filesystem path '/var/www/html/src') because search permissions are missing on a component of the path

很奇怪吧，于是我先去确认了 httpd.conf 里关于 `<Directory "/var/www/html">` 的配置(因为 Fedora19 的 httpd 版本是 2.4.6，我以为新版本有变化了)，然后去确认了 `/var/www/html/src` 的权限是不是 755，其他用户可读的。都没问题！

最后还是在 apache 的 httpd 官方文档上找到了关于这个错误码的详细解释，原来还有一种可能性，就是 SELinux 的安全控制！这个可以通过下面这个命令看到：

```bash
$ ls -lZ /var/www /var/www/html
/var/www:
drwxr-xr-x. root   root   system_u:object_r:httpd_sys_script_exec_t:s0 cgi-bin
drwxr-xr-x. apache apache system_u:object_r:httpd_sys_content_t:s0 html

/var/www/html:
drwxr-xr-x. chenlin.rao chenlin.rao unconfined_u:object_r:user_home_t:s0 src
```

看到没有，这里这些文件的 SELinux 类型是不一样的，默认的 `/var/www/html` 是 `httpd_sys_content_t`，`/var/www/cgi-bin` 是 `httpd_sys_script_exec_t`，而从我家目录移过去的 `/var/www/html/src` 是 `user_home_t`！

解决办法也很简单，把这个类型也改过来就好了：

```bash
$ chcon -R -t httpd_sys_content_t /var/www/html/src
```

这是第一次接触 SELinux 的安全管理，真的是好细致！
