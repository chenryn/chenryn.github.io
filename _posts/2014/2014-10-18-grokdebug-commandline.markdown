---
layout: post
title: 在终端命令行上调试 grok 表达式
date: 2014-10-18 23:43:00
category: logstash
tags:
  - ruby
---

用 logstash 的人都知道在 <http://grokdebug.herokuapp.com> 上面调试 grok 正则表达式。现在问题来了：<del>翻墙技术哪家强?</del> 页面中用到了来自 google 域名的 js 文件，所以访问经常性失败。所以，在终端上通过命令行方式快速调试成了必需品。

其实在 logstash 还在 1.1 的年代的时候，官方 wiki 上是有一批专门教大家怎么通过 irb 交互式测试 grok 表达式的。但不知道为什么后来 wiki 这页没了…… 好在代码本身不复杂，稍微写几行脚本，就可以达到目的了：

```ruby
#!/usr/bin/env ruby
require 'rubygems'
gem 'jls-grok', '=0.11.0'
require 'grok-pure'
require 'optparse'
require 'ap'

options = {}
ARGV.push('-h') if ARGV.size === 0
OptionParser.new do |opts|
  opts.banner = 'Run grokdebug at your terminal.'
  options[:dirs] = %w(patterns)
  options[:named] = false
  opts.on('-d DIR1,DIR2', '--dirs DIR1,DIR2', Array, 'Set grok patterns directories. Default: "./patterns"') do |value|
    options[:dirs] = value
  end
  opts.on('-m MESSAGE', '--msg MESSAGE', 'Your raw message to be matched') do |value|
    options[:message] = value
  end
  opts.on('-p PATTERN', '--pattern PATTERN', 'Your grok pattern to be compiled') do |value|
    options[:pattern] = value
  end
  opts.on('-n', '--named', 'Named captures only') do
    options[:named] = true
  end
end.parse!

grok = Grok.new
options[:dirs].each do |dir|
  if File.directory?(dir)
    dir = File.join(dir, "*")
  end
  Dir.glob(dir).each do |file|
    grok.add_patterns_from_file(file)
  end
end
grok.compile(options[:pattern], options[:named])
ap grok.match(options[:message]).captures()
```

测试一下：

    $ sudo gem install jls-grok awesome_print
    $ ruby grokdebug.rb
    Run grokdebug at your terminal.
        -d, --dirs DIR1,DIR2             Set grok patterns directories. Default: "./patterns"
        -m, --msg MESSAGE                Your raw message to be matched
        -p, --pattern PATTERN            Your grok pattern to be compiled
        -n, --named                      Named captures only
    $ ruby grokdebug.rb -m 'abc123' -p '%{NUMBER:test}'
    {
             "test" => [
            [0] "123"
        ],
        "BASE10NUM" => [
            [0] "123"
        ]
    }
    $ ruby grokdebug.rb -m 'abc123' -p '%{NUMBER:test:float}' -n
    {
        "test" => [
            [0] 123.0
        ]
    }

没错，我这比 grokdebug 网站还多了类型转换的功能。它用的 jls-grok 是 0.10.10 版，而我用的是最新的 0.11.0 版。 
