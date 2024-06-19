---
layout: post
theme:
  name: twitter
title: Puppet 自定义 type 和 function
category: devops
tags:
  - puppet
  - ruby
---
Puppet 除了原有 DSL 以外，还提供了不少接口方便大家开发插件来更简单的完成一些高级功能。

Define Type
===========

比如我们要维护一个上千域名组成的 ProxyServer 集群，其域名配置是相近的。那么我们就可以提炼出 template 里会变化的部分作为参数。由此定义出一个 type 如下：

```ruby
    define nginx::vhost4proxy(
        $iplist = [],
        $domainlist = [],
        $extconf = ''
    ) {
        $nginx_proxy_name    = $name
        $nginx_proxy_servers = $iplist
        $nginx_server_names  = $domainlist
    
        file { "${nginx_proxy_name}.server.conf":
            ensure  => file,
            require => File['/etc/nginx/conf.d'],
            path    => "/etc/nginx/conf.d/${nginx_proxy_name}.server.conf",
            content => template('nginx/vhost_proxy.conf.erb'),
            notify  => Service['nginx'],
        }
    }
```

然后在 template 里使用参数来生成结果：

```ruby
    upstream <%= nginx_proxy_name %> {
            consistent_hash $request_uri;
    <% nginx_proxy_servers.each do |ip| -%>
            server <%= ip %>;
    <% end %>
    }
    server {
        listen 80;
        server_name <% scope.lookupvar("nginx_server_names").each do |name| -%> <%= name -%><% end %>;
    
        location / {
            proxy_pass       http://<%= scope.lookupvar("nginx_proxy_name") %>;
            include          conf.d/proxy.conf;
        }
    <% if has_variable?("extconf") %>
        <%= scope.lookupvar("extconf") %>
    <% end %>
    }
```

这样我们只需要在 puppet 中这样调用，就可以直接生成对应的配置了：

```ruby
    nginx::vhost4proxy('server1':
        ['1.1.1.1 weight=2', '2.2.2.2 weight=3'],
        ['server1.domain', 'server1.alias.domain'],
        'access_log /path/to/other_log format'
    )
```

Custom Function
===============

不过用上面 define type 还不能完全解决我们提出的问题。因为在 puppet 配置里写几千行 nginx::vhost4proxy 也是一件很可怕的事情！

这时候可以更进一步，把 vhost4proxy 的调用过程隐藏成一个 function，如下：

```ruby
    require 'yaml'
    module Puppet::Parser::Functions
      newfunction(:gen_proxy_confd, :type => :statement) do |args|
        Puppet::Parser::Functions.autoloader.loadall
        resource_type = args[0]
        yaml_dir = args[1]
        Dir.foreach(yaml_dir) do |yaml_file|
          file_path = "#{yaml_dir}/#{yaml_file}"
          next unless file_path[-5..-1].eql?('.yaml')
          res_params = YAML.load_file(file_path)
          function_create_resources([resource_type, res_params])
        end
      end
    end
```

然后只要把原先传递给 vhost4proxy 的参数写成 yaml 文件放好就行了。

```yaml
    --- 
    server1: 
      iplist: 
        - 1.1.1.1 weight=2
        - 2.2.2.2 weight=3
      domainlist:
        - server1.domain
        - '*.server1.alias.domain'
      extconf: |-
        chunkin on;
        error_page 411 = @my_411_error;
        location @my_411_error {
            chunkin_resume;
        }
        access_log /path/to/other_log format;
```

大家看起来是不是有点眼熟？没错，这个 yaml 的思路完全是借鉴了 hiera 的写法。但是 hiera 的设计是垂直继承的，不适合这里假设的平面式的情况 —— 当然，如果你觉得把这几千个 yaml 都写在一个大 yaml 文件里也不费劲的话。就不用上我这么折腾了~~

最后在 puppet 配置中只用一行就搞定全部：

```ruby
    gen_proxy_confd('nginx::vhost4proxy',"${modulepath}/nginx/yaml")
```

要点
====

type 基本没有什么难度，因为他还是属于 puppet DSL 的运用。可以在其他配置文件内部直接写 define type，不过 puppet-lint 工具会报一个 warnings，所以建议还是单独拆分出来。

function 首先是路径和命名问题。

1. 要把写 function 的文件放在 `${modulepath}/yourmodule/lib/puppet/parser/functions/` 路径下；
2. 和其他 type、class 一样，文件名必须和 function 一致，puppet 才能 autoload；
3. 格式是固定的，注意有两种:type，statement和rvalue。如果你的 function 目的是返回一个值给 puppet 继续使用，要指定好。默认是 statement；
4. 在自定义 function 里调用其他 function 有两种办法，一种写全路径 `Puppet::Parser::Functions.function('file')`；一种是使用 `Puppet::Parser::Functions.autoloader.loadall` 加载全部 function，然后用 `function_**` 的方式来调用；
5. 示例中最关键的一个是调用了 `function_create_resources` 。`create_resources` 用来批量创建资源。直接在 puppet 配置文件里使用的时候，接收的是列表参数。但是在 Ruby 里直接使用 `function_create_resources` 的话，接收的是一个匿名数组作为唯一参数。
6. function 和 type 在 puppet 中可以认为是 class 的一种，所以它们也是有自己的作用域的。所以看到传递参数时写的是 "nginx::vhost4proxy"。

参考内容
========

关于 Facts 在 function 中的运用，rvalue 的示例等更多内容见官网：<http://docs.puppetlabs.com/guides/custom_functions.html>。

关于 puppet 自带的各种 function 的说明，见官网(很多也没写)：<http://docs.puppetlabs.com/references/latest/function.html>。

鸣谢
====

感谢 [@liu.cy](http://weibo.com/liucy1983) 童鞋提醒我变量作用域的问题。function 的调试过程很痛苦。
