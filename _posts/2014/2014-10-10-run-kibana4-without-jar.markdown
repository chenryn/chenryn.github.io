---
layout: post
title: 从源代码运行 Kibana 4
category: logstash
tags:
  - kibana
  - ruby
  - nodejs
---

Kibana 4 发布了，出人意料的是提供的居然是一个 jar 包的运行方式。好在有源码可看，根据源码可以分析得知，v4 版其实是一个 angularjs 写的 kibana 配上一个 sinatra 写的 proxyserver。这么一来，我们也就知道怎么来从源代码运行 Kibana 4，而不是用 Java 启动了。

{% highlight bash %}
# 安装 nodejs 和 npm 命令，仅用于下载依赖包，实际运行不需要
port install nodejs npm
# 下载 kibana 4 源码
git clone https://github.com/elasticsearch/kibana.git kibana4
cd kibana4/
# 安装 bower 工具
npm install -g bower
# 读取目录中的 bower.json，
# 依此下载所有 js 依赖库到其中定义的路径
# src/kibana/bower_components 下
bower install
cd src/server
# 安装 bundler 工具
gem install bundler
# 读取目录中的 Gemfile，
# 依此安装所有的 RubyGem 依赖库
bundle install
# 安装 lessc 工具
npm install -g less
# kibana 4 源码中在导入 lesshat 的时候都没写具体路径，所以要切换到对应目录下执行
cd ../src/kibana/bower_components/lesshat/build
# 编译 kibana 内的 *.less 文件为 *.css 文件
for i in `find ../../.. -name '[a-z]*.less' | grep -v bower_components`;do
    ../../../../../node_modules/.bin/lessc $i ${i/.less/.css/}
done
# 进入代理服务器目录
cd ../../../../server/
# 启动 sinatra 服务器
./bin/initialize
{% endhighlight %}

这样就可以通过 "localhost:5601" 访问了。

此外，Elasticsearch 集群的地址，在 `src/server/config/kibana.yml` 中配置。注意里面的 `kibana-int` 建议大家使用的时候改个名儿，不然万一跟你原先 kibana3 的混合在一起了就不好了。

最后，如果你的集群版本低于 1.4.0.BETA1，也不要着急，其实目前代码并没有用上什么这个版本的特性，所以可以通过修改 `src/kibana/index.js` 改变这个版本检测：

    --- a/src/kibana/index.js
    +++ b/src/kibana/index.js
    @@ -33,7 +33,7 @@ define(function (require) {
         // Use this for cache busting partials
         .constant('cacheBust', window.KIBANA_COMMIT_SHA)
         // The minimum Elasticsearch version required to run Kibana
    -    .constant('minimumElasticsearchVersion', '1.4.0.Beta1')
    +    .constant('minimumElasticsearchVersion', '1.1.0')
         // When we need to identify the current session of the app, ef shard preference
         .constant('sessionId', Date.now())
         // attach the route manager's known routes

Kibana 4 的界面，改成了 Query -> Visual -> Dashboard 三个解耦层次。而且不再是固定的提供某种某种 panel，改成自己选择、拼接甚至书写 Aggr 聚合函数的方式来灵活的生成图表。可以说，对使用者的 ES 知识，要求更高了。

后续如何发展，大家一起关注吧。
