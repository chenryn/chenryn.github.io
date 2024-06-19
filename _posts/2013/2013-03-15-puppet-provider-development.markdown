---
layout: post
theme:
  name: twitter
title: Puppet 自定义 Provider
category: devops
tags:
  - puppet
  - ruby 
---

Puppet 默认提供了相当多的资源类型，不过我们还可以更进一步的扩展这个庞大的阵营。比如在 `package` 类型的资源里，我们看到 puppet 除了系统级别的`yum`,`apt`之类意外，还提供了 `gem`,`pip` 来管理 ruby 和 python 的 package。那么很自然的，我们就可以进一步扩充 `package` 来管理 perl 的 package 。只需要新加一个 provider 就可以了。

关于 provider 开发的原理说明，见 <http://docs.puppetlabs.com/guides/provider_development.html>。

下面是 `/etc/puppet/modules/production/myclass/lib/puppet/provider/package/cpan.rb` 的内容，他会被 puppet 以 `pluginsync` 的方式下发。

```ruby
# 加载父类，这里是扩展 package 功能
require 'puppet/provider/package'

Puppet::Type.type(:package).provide :cpan, :parent => Puppet::Provider::Package do

  desc "CPAN modules support.  You can pass any `source` which `cpanm` support, 
    like URL, git repos and local tar.gz. If source is not present at all,
    the module will be installed from the default CPAN source.
    You must install App::cpanminus, App::pmodinfo, App::pmuninstall before."

  has_feature :versionable

  # 下面这个是 Puppet::Provider 提供的私有方法，用来指定类内部适用的系统命令
  # puppet agent 会通过对这个的运行测试来确认该 provider 是否适用于本机
  # 所以在使用这个 provider 之前，要先通过其他方式在 node 上安装好这三个命令
  commands :cpanmcmd => "cpanm"
  commands :pmodinfocmd => "pmodinfo"
  commands :pmuninstallcmd => "pm-uninstall"

  def self.pmodlist(options)
    pmodlist_command = [command(:pmodinfocmd),]

    if options[:local]
      pmodlist_command << "-l"
    else
      pmodlist_command << "-c"
    end
    if name = options[:justme]
      pmodlist_command << name
      # execute 是 Puppet::Util::Execution 提供的方法，接受数组传入，输出标准输出结果字符串
      list = [execute(pmodlist_command)].map {|set| pmodsplit(set) }.reject {|x| x.nil? }
    else
      list = execute(pmodlist_command).lines.map {|set| pmodsplit(set) }.reject {|x| x.nil? }
    end

    if name = options[:justme]
      return list.shift
    else
      return list
    end
  end

  def self.pmodsplit(desc)

    if desc =~ /^(\S+) version is (.+)\.(\n  Last cpan version: (.+))?/
      name = $1
      # 整个rb是从gem.rb复制过来的，gem list -r所有版本列成一行，split成一个数组
      # 这里为了改动少点，就照样做成数组
      versions = [$2]
      if latest_version = $3
        versions.unshift($4)
      end
      {
        :name     => name,
        :ensure   => versions,
        :provider => :cpan
      }
    else
      Puppet.warning "Could not match #{desc}" unless desc.chomp.empty?
      nil
    end
  end

  # 这个 instances 方法是 provider 必须提供，在package里就是本地模块的列表
  def self.instances(justme = false)
    pmodlist(:local => true).collect do |hash|
      new(hash)
    end
  end

  # 往下的方法都是 package 要求提供的
  def install(useversion = true)
    command = [command(:cpanmcmd)]
    # cpanm 指定安装版本的命令格式是这样： cpanm Dancer@1.000
    resource[:name] += '@' + resource[:ensure] if (! resource[:ensure].is_a? Symbol) and useversion
    command << resource[:name]

    output = execute(command)
    self.fail "Could not install: #{output.chomp}" if output.include?("failed")
  end

  def latest
    pmodinfo_options = {:justme => resource[:name]}
    hash = self.class.pmodlist(pmodlist_options)
    # 这里就是前面要用数组的原因了
    hash[:ensure][0]
  end

  # 请求本地是否存在具体某个包
  def query
    self.class.pmodlist(:justme => resource[:name], :local => true)
  end

  def uninstall
    pmuninstallcmd resource[:name]
  end

  def update
    self.install(false)
  end
end
```

在一台没有安装 cpanm 等命令的主机上运行 `puppet agent --debug`，可以看到这么一行输出：

    debug: Puppet::Type::Package::ProviderCpan: file cpanm does not exist

