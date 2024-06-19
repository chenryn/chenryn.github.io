---
layout: post
theme:
  name: twitter
title: 巧用 Puppet 的 stdlib 库
category: devops
tags:
  - puppet
  - ruby
---

这几天上线机器给 Elasticsearch 集群扩容，开始撰写 Puppet 的 elasticsearch 类来规范化管理。这里碰到一个小问题，相信在很多大容量集群的机器上都会有。那就是每台机器上都挂载有十几二十块磁盘，怎么用 Puppet 给快速方便的创建各磁盘上的工作目录呢？

一个一个写 File 资源申明肯定不可取；File 资源申明支持接受数组，但是二十多个元素写一个大数组也没方便到哪里去。有没有比较简单的办法来生成这个大数组，而不是手写呢？

有，就是使用 Puppet 官方出的这个 stdlib 库 <http://forge.puppetlabs.com/puppetlabs/stdlib>。

安装方法很简单，在 Puppet Master 上运行命令 `puppet module install puppetlabs-stdlib` 即可。

因为 puppet 默认会分发所有 module 的 lib/ 目录，所以即便你没有在自己的类里 `import stdlib`，也是可以直接使用它提供的各种函数的。

下面就是我的 elsticsearch 类配置：

```ruby
class elasticsearch {

    $esdatadir = suffix( prefix( range(1, $::datadircount-1), '/data'), '/elasticsearch')

    package {['java-1.7.0-openjdk', 'elasticsearch']:
        ensure  => 'present',
        require => Class['repos'],
    }->
    file {$esdatadir:
        ensure  => 'directory',
        owner   => 'elasticsearch',
    }->
    file {'/etc/elasticsearch/elasticsearch.yml':
        ensure  => 'file',
        owner   => 'elasticsearch',
        content => template('elasticsearch/elasticsearch.yml.erb'),
    }
    }~>
    service {'elasticsearch':
        ensure  => true,
        enable  => true,
    }
}
```

其中 `$::datadircount` 是我自定义的 Facts 变量，插件代码见两年前的博客[《puppet安装／Facter插件和puppet模板编写》](http://chenlinux.com/2012/05/10/quick-start-for-puppet-facter-erb)。

然后 `elasticsearch.yml.erb` 里的数据目录配置定义如下：

```ruby
path.data:
<% scope.lookupvar("elasticsearch::esdatadir").each do |dir| -%>
  - <%= dir %>
<% end %>
```

`puppetlibs-stdlib` 实现了很多对基础类型的扩展函数，比如本例中用到了 `range`、`prefix` 和 `suffix` 三个。依次生成了 1 到 N 的数组，给数组每个元素加上 `/data` 前缀字符串，再给每个元素加上 `/elasticsearch` 后缀字符串，最后变成了 `/dataN/elasticsearch` 这种格式的元素构成的数组。

`puppetlibs-stdlib` 实现的非常漂亮的地方是，很多函数都根据常见用途提供了不同场景下的不同行为。

* 比如 `range` 即可以 1 到 N，也可以 01 到 NN，甚至可以先加上 prefix 后再 '/data1' 到 '/dataN' 都支持。
* 比如 `unique` 既可以针对字符串去重，也可以针对数组元素去重。

更多函数说明，见源码仓库 [README](https://github.com/puppetlabs/puppetlabs-stdlib/blob/master/README.markdown) 文档。

