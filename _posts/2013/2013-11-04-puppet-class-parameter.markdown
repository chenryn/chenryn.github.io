---
layout: post
title: Puppet 的类参数传递
category: puppet
---

之前使用 ENC 管理 puppet，尽量保持了输出 yaml 内容的简单，只提供了一个统一的全局参数定义 node 的 role。(题外话，puppetlabs 推荐了另一个通过继承关系实现 role 的示例，见：[Designing Puppet - Roles and Profiles](http://www.craigdunn.org/2012/05/239/)。)

但是 puppet 中有些配置确实修改比较频繁，文件操作不得不说是一件不甚方便的事情，于是重新考虑通过类参数的方式来灵活化某些配置的操作。

修改前
=========================

### nginx/manifests/init.pp

{% highlight ruby %}
class nginx {
    include "nginx::${::role}"
}
{% endhighlight %}

### nginx/manifests/loadbalancer.pp

{% highlight ruby %}
class nginx::loadbalancer {
    $iplist = ['192.168.0.2:80']
    file { 'nginx.conf':
        content => template('nginx/nginx.conf.erb'),
    }
}
{% endhighlight %}

### enc nginxhostname

{% highlight yaml %}
---
classes:
  - nginx
  - base
environment: production
parameters:
  role: loadbalancer
{% endhighlight %}

修改后
=================

### nginx/manifests/init.pp

{% highlight ruby %}
class nginx ($iplist = []) {
    class { "nginx::${::role}":
        iplist => $iplist
    }
}
{% endhighlight %}

### nginx/manifests/loadbalancer.pp

{% highlight ruby %}
class nginx::loadbalancer ($iplist = []) {
    file { 'nginx.conf':
        content => template('nginx/nginx.conf.erb'),
    }
}
{% endhighlight %}

### enc nginxhostname

{% highlight yaml %}
---
classes:
  nginx:
    iplist:
      - 192.168.0.2:80
  base: ~
environment: production
parameters:
  role: loadbalancer

}
{% endhighlight %}

要点
================

1. 虽然真正需要 $iplist 的是下面的一个子类，但是 ENC 传值是给的父类，所以需要一层层传递下去；
2. ENC 中给类传参，类就要写成哈希形式，否则是数组形式；
3. 有参数的类，在调用的时候无法使用 `include` 形式的写法，只能用资源调用形式的写法。

修改中出现了一个很搞笑的错误，因为是在 vim 里批量转换，结果子类名字后面多了一个空格，成了`class { "nginx::${::role} ":`这样。结果 puppet 一直返回报错说 "Invalid Parameter"。这时候一个习惯性的思维造成了误会：我们一般会认为`:`后面的那一行行键值对才是 parameter，但其实这里子类名也是 `class` 这个资源调用的 parameter。当然，如果可以在这里报一个 `Class Not Found` 就更好了。
