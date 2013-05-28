---
layout: post
title: 给 puppet 写 Rspec 测试用例
category: devops
tags:
  - puppet
  - ruby
---
上文提到 github 给 puppet 开发的几个附件。其中有扩展 rspec 的 rubygems 模块叫做 rspec-puppet。官网见：<http://rspec-puppet.com>

照着官网 [Tutorial](http://rspec-puppet.com/tutorial/)，很容易能写出来测试用例。我这样ruby入门没看完的水准，从发现这个gem到写完第一个测试用例，也就花了不到半个小时。

# 安装

{% highlight bash %}
    gem install puppetlabs_spec_helper rspec_puppet
{% endhighlight %}

# 创建测试用例环境

以测试 nginx 模块为例：

{% highlight bash %}
    cd /etc/puppet/modules/nginx
    rspec-puppet-init
{% endhighlight %}

这个 init 脚本其实就是执行了一串 `mkdir -p` 和 `ln -s` 命令，最后生成一个总的 Rakefile 。详情见官网[Setup](http://rspec-puppet.com/setup/)。

# 编写测试用例

扩展给 Rspec 增加的方法其实不多，官网 [Matchers](http://rspec-puppet.com/matchers/) 页面上有说。主要就是下面几个：

* `include_class()`
* `contain_<resource>()`
* `run()`
* `.with()`
* `.without()`

现在来写我们的第一个测试用例 `/etc/puppet/modules/nginx/spec/classes/common_spec.rb` 吧：

{% highlight ruby %}
    # 这个文件被 init 自动生成在 /etc/puppet/modules/nginx/spec/ 下了
    # 其内容就是加入这个目录下所有的文件
    require 'spec_helper'
    # 这里定义你要测试的 puppet module
    describe 'nginx' do
        it do
            should include_class('nginx::sysctl')
            should include_class('nginx::install')
        end
    end
    
    describe 'nginx::common' do
        # 使用let定义变量
        let(:node) { 'common-nginx-2.domain.com' }
        # 不定义的话，测试中只有从前面:node 生成的 hostname,domain,fqdn 三个
        let(:facts) { {
            :ipaddress_eth0 => '192.168.1.2',
            :processorcount => '8',
        } }
        it do
            should include_class('nginx::common')
            # 注意这里要写 Resource 的名字，而不是 file 的 path
            # 这个是下面 .with 检查的 :param
            should contain_file('proxy.conf').with({
                'ensure' => 'file',
                'mode'   => '0644',
                'path'   => '/etc/nginx/conf.d/proxy.conf'
            })
        end
        context 'access_log' do
            expect_line = 'access_log /data/nginx/logs/access.log main buffer=16k;'
            it do
                # 注意这里是把整个 content 作为 String 对象传递
                should contain_file('nginx.conf').with_content(/#{expect_line}/)
            end
        end
        context 'upstream' do
            expect_line = '192.168.1.2:80;'
            it do
                should contain_file('upstream.conf').with_content(/#{expect_line}/)
            end
        end
        context 'conf.d' do
            it do
                dir = '/etc/puppet/modules/nginx/files/conf.d'
                # eq 是 rspec 本身的方法
                Dir.entries(dir).length.should eq(15)
            end
        end
    end
{% endhighlight %}

然后你就可以运行测试了：

{% highlight bash %}
    cd /etc/puppet/modules/nginx
    rake spec
{% endhighlight %}

如果测试用例有失败，会在终端看到错误信息。

注意到，rspec 是以 `do ... end` 来计算 examples 个数的。在一个 `do ... end` 里写多个 should 或者 expect，也算一个 example。

