---
layout: post
title: 使用 Foreman 来监控统计 puppet 的 reports 信息
category: puppet
---
foreman 是社区比较推荐的一款 puppet 辅助工具。可以用来实现 ENC 控制，class 编写，Facts 变量统计和 reports 分析查询等等。

鉴于我一直以来都是用 gem 安装 puppet，所以这里也就没法通过 yum/apt 来安装 foreman，只能源码操作了：

{% highlight bash %}
    git clone https://github.com/theforeman/foreman.git -b develop
    cd foreman
    bundle install --without postgresql mysql mysql2 
    cp config/settings.yaml.example config/settings.yaml
    cp config/database.yml.example config/database.yml
    RAILS_ENV=production bundle exec rake db:migrate
    rake puppet:import:hosts_and_facts RAILS_ENV=production
    ./script/rails server -p 3333 -e production -d
{% endhighlight %}

然后就可以通过3333端口访问并查看刚才导入的 Facts 变量了，默认的用户名密码是 admin/changeme。

新版本的 foreman，必须使用 smart-proxy 才能接收 reports。所以还要继续安装：

{% highlight bash %}
    git clone git://github.com/theforeman/smart-proxy.git
    cd smart-proxy
    sed -i 's/^#:puppet:.*/:puppet: true/' config/settings.yml
    ./bin/smart-proxy.rb
{% endhighlight %}

foreman 提供了一个 [ruby 脚本](https://raw.github.com/theforeman/puppet-foreman/master/templates/foreman-report.rb.erb)，用来扩充 puppet 的 reports 功能。下载放到对应的 `${GEM_PATH}/gems/puppet-${version}/lib/puppet/reports/` 下，然后修改其中的 `$foreman_url` 变量即可。

我们也可以在 puppet 自带的 http.rb 基础上稍微修改得到相同效果，总的来说，就是通过 POST 方法，提交 `report => self.to_yaml` 到 `$foreman_url/reports/create?format=yml` 就可以了。

然后在 foreman 页面上配置 smart-proxy 地址。注意这里有个小坑：__如果你填写的是域名，那么解析出来的 ip 还要被反解验证一次。__我当初为了 puppet master 迁移方便，给 master 配置了一个单独的域名，包括 `puppet cert` 生成证书时也特意指定用这个域名，但是默认的 hostname 其实是另一个域名的。于是在此悲剧了很久。。。

错误的现象是：采用 `puppet master` 启动时，功能一切正常；采用 `rackup` + Nginx 代理的方式启动时，默认的 store 功能正常，而采用 foreman 接收 reports 的话，可以在 `rackup` 的访问日志中看到 POST 200 的记录，`foreman` 里却没有接到请求。

目前还不清楚为什么两种不同方式启动 puppet 的 master 会对 smart-proxy 造成什么区别影响，但是修改 foreman 里配置的 smart-proxy 地址为默认 hostname 而不是单独的域名后，就成功了。

另外一个使用上的小问题。foreman 页面上的 Reports 标签的 `<a href="">` 属性默认是带搜索参数 eventful 的。也就是说优先展示的是有事件发生的日志，比如 failed，restart 等等；而不是直接以日期排序。

