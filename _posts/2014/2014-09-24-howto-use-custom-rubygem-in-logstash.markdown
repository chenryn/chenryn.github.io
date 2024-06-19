---
layout: post
theme:
  name: twitter
title: 在 logstash 里使用其他 RubyGems 模块
category: logstash
tags:
  - java
  - ruby
---

在开发和使用一些 logstash 自定义插件的时候，几乎不可避免会导入其他 RubyGems 模块 —— 因为都用不上模块的小型处理，直接写在 *filters/ruby* 插件配置里就够了 —— 这时候，运行 logstash 命令可能会发现一个问题：这个 gem 模块一直是 "no found" 状态。

这其实是因为我们一般是通过 java 命令来运行的 logstash，这时候它回去寻找的 Gem 路径跟我们预计中的是不一致的。

要查看 logstash 运行时实际的 Gem 查找路径，首先要通过 `ps aux` 命令确定 ruby 的实际运行方式：

    $ ps uax|grep logstash
    raochenlin      27268  38.0  4.3  3268156 181344 s003  S+    7:10PM   0:22.36 /Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java -Xmx500m -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -Djava.awt.headless=true -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -jar /Downloads/logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar -I/Users/raochenlin/Downloads/logstash-1.4.2/lib /Users/raochenlin/Downloads/logstash-1.4.2/lib/logstash/runner.rb agent -f test.conf

看，实际的运行方式应该是：`java -jar logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar -Ilogstash-1.4.2/lib logstash-1.4.2/lib/logstash/runner.rb` 这样。

那么我们查看 gem 路径的命令也就知道怎么写了：

    java -jar logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar `which gem` env

你会看到这样的输出：

>    RubyGems Environment:
>      - RUBYGEMS VERSION: 2.1.9
>      - RUBY VERSION: 1.9.3 (2014-02-24 patchlevel 392) [java]
>      - INSTALLATION DIRECTORY: file:/Downloads/logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/lib/ruby/gems/shared
>      - RUBY EXECUTABLE: java -jar /Downloads/logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar
>      - EXECUTABLE DIRECTORY: file:/Downloads/logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/bin
>      - SPEC CACHE DIRECTORY: /.gem/specs
>      - RUBYGEMS PLATFORMS:
>        - ruby
>        - universal-java-1.7
>      - GEM PATHS:
>         - file:/Downloads/logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/lib/ruby/gems/shared
>         - /.gem/jruby/1.9
>      - GEM CONFIGURATION:
>         - :update_sources => true
>         - :verbose => true
>         - :backtrace => false
>         - :bulk_threshold => 1000
>         - "install" => "--no-rdoc --no-ri --env-shebang"
>         - "update" => "--no-rdoc --no-ri --env-shebang"
>         - :sources => ["http://ruby.taobao.org/"]
>      - REMOTE SOURCES:
>         - http://ruby.taobao.org/
>      - SHELL PATH:
>         - /usr/bin
>         - /bin
>         - /usr/sbin
>         - /sbin
>         - /usr/local/bin

看到其中的 GEM PATHS 部分，是一个以 **file:** 开头的路径！也就是说，要求所有的 gem 包都打包在这个 jruby-complete-1.7.11.jar 里面才认。

所以我们需要把额外的 gem 包，也加入这个 jar 里：

    jar uf jruby-completa-1.7.11.jar META-INF/jruby.home/lib/ruby/1.9/CUSTOM_RUBY_GEM_LIB

*注：加入 jar 是用的相对路径，所以前面这串目录要提前创建然后复制文件进去。*

当然，其实还有另一个办法。

让我们返回去再看一次 logstash 的进程，在 jar 后面，还有一个 `-I` 参数！所以，其实我们还可以把文件安装在 `logstash-1.4.2/lib` 目录下去。

最后，你可能会问：那 `--pluginpath` 参数指定的位置可不可以呢？

答案是：也可以。

这个参数指定的位置在 *logstash-1.4.2/lib/logstash/agent.rb* 中，被加入了 `$LOAD_PATH` 中：

```ruby
  def configure_plugin_path(paths)
    paths.each do |path|
      if !Dir.exists?(path)
        warn(I18n.t("logstash.agent.configuration.plugin_path_missing",
                    :path => path))
      end
      plugin_glob = File.join(path, "logstash", "{inputs,codecs,filters,outputs}", "*.rb")
      if Dir.glob(plugin_glob).empty?
        @logger.warn(I18n.t("logstash.agent.configuration.no_plugins_found",
                    :path => path, :plugin_glob => plugin_glob))
      end
      @logger.debug("Adding plugin path", :path => path)
      $LOAD_PATH.unshift(path)
    end
  end
```

`$LOAD_PATH` 是 Ruby 的一个特殊变量，类似于 Perl 的 `@INC` 或者 Java 的 `class_path` 。在这个数组里的路径下的文件，都可以被 require 导入。

可以运行如下命令查看：

    $ java -jar logstash-1.4.2/vendor/jar/jruby-complete-1.7.11.jar -e 'p $LOAD_PATH'
    ["file:/Users/raochenlin/Downloads/logstash-1.4.2/vendor/jar/rar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/lib/ruby/1.9/site_ruby", "file:/Users/raochenlin/Downloads/logstash-1.4.2/vendor/jar/rar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/lib/ruby/shared", "file:/Users/raochenlin/Downloads/logstash-1.4.2/vendor/jar/rar/jruby-complete-1.7.11.jar!/META-INF/jruby.home/lib/ruby/1.9"]

这三种方式，你喜欢哪种呢？
