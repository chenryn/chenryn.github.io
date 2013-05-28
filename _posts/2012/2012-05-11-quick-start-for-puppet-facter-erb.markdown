---
layout: post
title: 【puppet系列】puppet安装／Facter插件和puppet模板编写
date: 2012-05-10
category: devops
tags:
  - puppet
  - ruby
---

使用puppet管理集群配置是个很靠谱的做法。跟其他同类产品相比，第一他的DSL语法很丰富够灵活，第二围绕他的生态圈活跃，资料比较多。

# puppet安装

由于关注热度比较高，所以各种简便安装办法都出来了。大家可以各自选择，走yum、apt或者src都行。我这里演示一下用rubygems的办法。优点是不用像yum那样找epel源，而且版本够新，缺点是没有yum自动出来的配置目录和管理脚本。
{% highlight bash %}
#!/usr/bin/env bash
# Set Curlrc for https
echo 'insecure' >> ~/.curlrc
# Install git
curl -L get-git.rvm.io | sudo bash
# Install RVM
curl -L get.rvm.io | sudo bash -s stable
# Install Last Ruby
source "/usr/local/rvm/scripts/rvm"
rvm install 1.9.3
# Use GEM Mirror in Taobao
gem sources -r http://rubygems.org/
gem sources -a http://rubygems.taobao.org/
# Install puppet
gem install puppet --no-ri --no-rdoc
groupadd puppet
useradd -g puppet -s /bin/false -M puppet
# Get default puppet config
mkdir /etc/puppet
puppet --genconfig > /etc/puppet/puppet.conf
{% endhighlight %}
需要说明一点，puppet对集群的识别高度依赖fdqn，所以必须保证主机名和IP的一一对应。我的环境里因为本身kerberos认证也是fdqn依赖的，所以反而省事不少，其他环境中，估计折腾dns或者hosts也是个大步骤。    

# facter简介

在安装puppet的时候，会顺带安装好facter工具，这个工具是用来探测本机各类变量，提供给puppetd使用的。    

因为facter也是ruby写的。所以我们可以自己根据其规则书写补充工具获取更多的变量，方便之后定制模块和类资源。

# puppetca认证

安装完成后需要建立认证关系。puppet没有像其他通用系统一样借用sshkey的认证，而是自己维护了一套，所以有这么个单独的章节：    

首先是客户端上的申请，没有单独的命令，就跟一次正常请求一样即可：    
{% highlight bash %}
    puppetd --test --server master.pp.domain.com    
{% endhighlight %}

注意：因为puppet2.7和ruby1.9.2以上版本在ssl上的冲突，所以新版本ruby的client需要多几步处理：    
{% highlight bash %}
scp master.puppet.domain.com:/etc/puppet/ssl/certs/ca.pem /etc/puppet/ssl/certs/
hash=`openssl x509 -hash -noout -in /etc/puppet/ssl/certs/ca.pem`
ln -s /etc/puppet/ssl/certs/ca.pem /etc/pki/tls/certs/${hash}.0
{% endhighlight %}

这样才能正常申请cert。    

然后在主控端上审批。首先可以puppetca --list查看有多少请求过来的client是未认证的。然后运行如下命令通过：    
{% highlight bash %}
    puppetca -s -a    
{% endhighlight %}
(吐槽一下，内网上已经有这么多认证了，还搞一套pp的，还搞出问题来了，有够无聊的，强烈希望pp提供一个开关)

# site.pp简介

/etc/puppet/manifests/site.pp是puppetmaster的总入口。在这里主要完成几个工作：加载模块(import "module")；加载节点配置(node {})。    

模块的名字，就是直接来自于/etc/puppet/modules/dir_name的命名；而node里include包含的class类名，则是modules/dir_name/manifests/init.pp中写的名字。    

一般来说，这两个可以保持一致方便管理。但是规则毕竟如此，碰到不一致的还是要懂（我就是碰上不一致的样例才研究的）。    

node配置太多的话，可以另外写在别的目录和配置文件里。在site.pp中只要`include 'nodes/*.pp'`这样就可以了。

node配置主要三个部分：    

1. node的fdqn的正则匹配；    
2. node的变量赋值；    
3. node的特定类；    

比如下面这个例子：
{% highlight ruby %}
node "cache[0-9]\.domain\.com" {
  $var = "strings"
  $array = ["one", "two"]
  include facter squid
}
{% endhighlight %}

# modules简介

模块中一定有manifests/init.pp作为入口，然后根据其中的定义，另外有templates和files作为辅助目录。    

init.pp中可以使用require 'other.pp'指令来加载模块的其他配置。    

init.pp中可以使用puppet的各种资源，包括file、service、exec、package、cron、user等等。    

各种资源下有各种属性和方法可用，这里就不展开讲了，一来我也没掌握多少，二来真写全了够出书了。主要写关于file的几个，因为linux的本质就是All is file嘛~    

1. content:直接在puppet配置里写file的内容，一般只会在测试的时候这么直接用。更多的是用template('class/class.template.erb')的方式调用模板文件。    
2. source:直接下载puppetmaster上的原始文件，具体url写法是puppet:///module/file。    
3. notify:在客户端搞定file的写入后准备触发的下一个操作，一般用来重启服务(可以用service方法，也可以用exec方法)等等。    
4. ensure:file的状态。比如absent是如果已存在的就删除掉；present是如果不存在就新建；directory是目录；latest是最新的包版本等等。    
5. path:file在客户端的真是存放路径。如果没有定义，就是用name配置。    
6. mode:file在客户端的权限，也就是644,755之类的。

# template简介

puppet用的erb模板引擎，也是RoR中用的模板引擎。看起来和Perl5中的Template::Toolkit相当的一样。尤其是<%%>里使用=和-的表现。    

我们可以在puppet里用erb完成比puppet语法复杂的多的功能，比如根据node的变量进行运算、循环、判断等等。    

# squid示例

最后举例今天完成的一个简单的squid的配置。

首先是/etc/puppet/manifests/site.pp：    
{% highlight ruby %}
import "squid"
node "cache[0-9]\.domain\.com" {

  $cache_peers = [ '1.2.3.4', '1.2.3.5']
  $http_port = "8080"
  $fs_type = "aufs"
#  单独区分coss，是因为squid源码被修改过后，关于COSS的配置跟磁盘都是特制的，不能像原版那样计算了 
#  $fs_type = "coss"
#  $coss_options = "/data/coss/stripe0 32 backstore=/data/coss/stripe4,32 max-size=1024768 block-size=1024"

  include facter squid
}
{% endhighlight %}

然后是/etc/puppet/modules/facter/manifests/init.pp:

{% highlight ruby %}
class facter {
    file { "df.rb":
        path   => "/usr/lib/ruby/gems/1.8/gems/facter-1.6.8/lib/facter/df.rb",
        ensure => file,
        mode   => 644,
        source => "puppet:///modules/facter/df.rb",
    }
}
{% endhighlight %}

关于给facter写插件，网站的资料说的path都是直接在#{rubysitedir}/facter目录下。但我这里实际情况却不是(好吧，暴露了我的实验机并没有按照上面说的用rvm安装ruby而是yum的)。    
__2013年1月31日更正：__
更优的做法应该是放在`#{puppetdir}/modules/yourmodule/lib/facter/`下，然后作为pluginsync发下去。
__更正以上__

然后是对应的/etc/puppet/modules/facter/files/df.rb:

{% highlight ruby %}
data_dir_list = {}
df = Facter::Util::Resolution.exec("/bin/df -m 2>/dev/null")
df.each_line do |l|
  if l =~ /^\/dev\/\w+\s+(\d+).+\/(data\d*)$/
    data_dir_list[$2] = $1
  end
end
Facter.add("DataDirCount") do
  setcode do
    if data_dir_list.length != 0
      data_dir_list.length
    end
  end
end

data_dir_list.each do |k,v|
  Facter.add("DirSize_#{k}") do
    setcode do
      v
    end
  end
end
{% endhighlight %}

实现很简单，实质就是执行df -m，获取挂载点为/data、/data1...的目录数以及各目录的总大小，然后把结果添加到facter里。之所以要加这么个插件，是因为之后squid的缓存目录，需要根据目录数量和大小自动计算，而标准的facter里没有这方面的信息，无法传递相关变量。    

下面正式进入squid模块部分。看/etc/puppet/modules/squid/manifests/init.pp:

{% highlight ruby %}
class squid {
    service { "squid":
        ensure    => running,
        subscribe => File["squid.conf"],
    }
    file { "squid.conf":
        path    => "/tmp/squid.conf",
        notify  => Service["squid"],
        content => template("squid/squid.conf.erb"),
        ensure  => present,
    }
}
{% endhighlight %}
这里只写了service和file两个，实际上还应该有package保证client上确实有squid软件，有file保证/etc/init.d/squid脚本存在等等。注意其中file里的notify和service里的subscribe正好是对应的意思。    

最后是/etc/puppet/squid/template/squid.conf.erb:
{% highlight squid %}
<% if (fs_type == 'aufs') -%>
cache_dir aufs /data/fcache <%= Integer(dirsize_data.to_i*0.8) %> 16 256
<% if (datadircount.to_i > 1) -%>
<% 1.upto(datadircount.to_i - 1).each do |i| -%>
<% size = eval "dirsize_data#{i}" -%>
cache_dir aufs /data<%= i %>/fcache <%= Integer(size.to_i*0.8) %> 16 256
<% end -%>
<% end -%>
<% else %>
cache_dir coss <%= coss_options %>
<% end %>
cache_mem <%= Integer(memorysize.to_i * 0.45 * 1024) %> MB
visible_hostname <%= fqdn %>
http_port <%= http_port %> vhost

<% cache_peers.each do |peer| -%>
cache_peer <%= peer %> parent 80 0 no-query originserver round-robin
<% end %>
{% endhighlight %}
这里只贴跟模板变量相关的部分。初学ruby，被to_i方法搞得很是郁闷，还好像eval方法之类的很像很眼熟~~    
模板里cache_peers等，是在node配置里定义的；memorysize等，是facter获取的。
