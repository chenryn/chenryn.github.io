---
layout: post
title: Serverspec 工具介绍
category: devops
tags:
  - rspec
  - ruby
  - puppet
---

去年曾经写过一篇[文章](http://chenlinux.com/2013/01/10/rspec-puppet-intro)里提到做 puppet 的测试，用的是 [rspec-puppet](http://rspec-puppet.com) 工具。不过这个工具的作用只是能确保在 Puppet Master 上你撰写的 .pp 文件可以按照你的预期正常编译完毕，并不代表真实的节点就是按照这个状态维护的。所以今天介绍另一个工具，Serverspec，它拥有和 rspec-puppet 类似的语法(都是 Rspec 衍生品)，同时又是真的 SSH 到远程主机上去做测试！官网见：<http://serverspec.org>。

安装直接通过 `gem install serverspec` 方式即可完成。然后通过 `serverspec-init` 命令可以创建处理来一个测试模板：

    .
    ├── Rakefile
    └── spec
        ├── 10.4.1.21
        │   └── puppet_spec.rb
        ├── spec_helper.rb

文件其实非常简单，所以之后就可以不用命令，自己创建目录和测试文件好了。目录以远端主机 IP 命名，测试文件叫 `foobar_spec.rb` 也没关系，反正在 Rakefile 里是通过 `spec/*/*_spec.rb` 载入的。

下面是我写的这个 `puppet_spec.rb` 实例：

{% highlight ruby %}
require 'spec_helper'

describe "system" do
  # TODO: bonding
  context interface('eth2') do
    it { should have_ipv4_address("192.168.0.200") }
    its(:speed) { should eq 1000 }
  end
  context file('/data') do
    it { should be_mounted.with( :type => 'ext4' ) }
  end
  context linux_kernel_parameter('vm.swappiness') do
      its(:value) { should eq 0 }
  end
  context yumrepo('epel') do
    it { should exist }
    it { should_not be_enabled }
  end
end

describe "puppetmaster" do
  context group('puppet') do
    it { should exist }
  end
  context user('puppet') do
    it { should exist }
    it { should belong_to_group 'puppet' }
    it { should_not have_login_shell '/bin/sh' }
  end
  context package('puppet') do
    it { should be_installed.by('gem').with_version('3.6.1') }
  end
  context package('nginx') do
    it { should be_installed }
  end
  context service('nginx') do
    it { should be_enabled   }
    it { should be_running   }
  end
  %w[8140 18140].each do |port|
    context port(port) do
      it { should be_listening }
    end
  end
  context file('/etc/nginx/sites-enabled/puppet') do
    it { should be_linked_to '/etc/puppet/webui/ngx_puppetmaster.conf' }
    it { should be_readable.by_user('nobody') }
    its(:content) { should match /\n  server 127.0.0.1:18140;/ }
  end
  context command("nginx -t") do
    it { should return_stderr /ok/ }
    it { should return_exit_status 0 }
  end
end

describe process('rrdcached') do
  it { should be_running }
  its(:args) { should match /-j \/omd\/sites\/cdn\/var\/rrdcached/ }
end
{% endhighlight %}

基本上可以说跟 puppet 最常用的几个类型对应的测试就都在上面展示了。此外，Serverspec 与时俱进，还提供了 `cgroup` 和 `lxc` 的测试器。这里就没写了。

这里有个注意到的问题就是网卡速度那里，是不支持测试 bonding 网卡的。它 ssh 上去后其实就是执行 ethtool 命令，ethtool 命令获取不到，自然也就没法测试，肯定会报测试失败。

另一个问题就是文件内容匹配那块，虽然文档示例里用了 `/^begin/` 但是实测这个会把整个文本读成一个大字符串来匹配，所以单行的开头不能用 `^` 而是用 `\n` 来做。

正常情况下，写完测试用例，就可以运行 `rake spec` 命令跑测试了。不过熟悉我的朋友都知道人人网这边服务器都是统一通过 Kerberos 认证来管理权限的，而 各种语言的 SSH 模块默认都不太支持 krb5。所以我这还需要先解决 Serverspec 的 krb5 支持问题。

感谢 [@懒桃儿吃桃儿](http://weibo.com/u/1653644220) 童鞋贡献的[模块](https://github.com/Lax/net-ssh-kerberos)，部署过程如下：

    $ git clone https://github.com/Lax/net-ssh-kerberos.git
    $ pushd net-ssh-kerberos
    $ gem build net-ssh-kerberos.gemspec
    $ gem install net-ssh-krb-0.3.0.gem
    $ popd
    $ diff spec/spec_helper.rb spec/spec_helper.rb.orig
    4,5d3
    < require 'rubygems'
    < require 'net/ssh/kerberos'
    29d26
    <       options[:auth_methods] = ["gssapi-with-mic"]

模块文档上说可以通过 Gemfile 配合 `Bundler.require` 指令直接运行，我测试自己写脚本的话确实没有问题，但是融合到 `spec_helper.rb` 里就不行，所以只能自行编译安装，然后通过 rubygems 模块来加载了。

最后，就可以看到下面这样的输出了：

    $ rake spec
    /usr/bin/ruby -S rspec spec/10.4.1.21/nginx_spec.rb
    .......................
    
    Finished in 9.99 seconds
    23 examples, 0 failures

