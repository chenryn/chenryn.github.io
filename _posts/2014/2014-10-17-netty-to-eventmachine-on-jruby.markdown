---
layout: post
theme:
  name: twitter
title: 在 JRuby 上用 netty 模拟 eventmachine
category: ruby
tags:
  - java
---

上一篇说到在 JRuby 上利用 netty 库实现事件驱动。事实上，为了让 Ruby 程序员更习惯，foxbat 模块是把 netty 库封装成 eventmachine 的接口来提供给用户使用的。所以，我们可以把程序写得更通用一些：

```ruby
  if defined?(JRUBY_VERSION)
    require 'foxbat'
  end
  require 'eventmachine'
  require 'socket'

  module SyslogRecv
    def initialize(options)
      @output_queue = options[:queue]
      @codec = options[:codec]
      @grok_filter = options[:grok_filter]
      @date_filter = options[:date_filter]
    end
    def syslog_relay(event)
      @grok_filter.filter(event)
      if event["tags"].nil? || !event["tags"].include?("_grokparsefailure")
        event["timestamp"] = event["timestamp8601"] if event.include?("timestamp8601")
        @date_filter.filter(event)
      else
        @logger.info? && @logger.info("NOT SYSLOG", :message => event["message"])
      end
    end
    def post_init
      (@@connections ||= []) << self
    end
    def receive_data(data)
      @@connections.each do |client|
        if defined?(JRUBY_VERSION)
          ip = client.get_peername.getAddress.getHostAddress
          port = client.get_peername.getPort
        else
          port, ip = Socket.unpack_sockaddr_in(client.get_peername)
        end
        ::LogStash::Util::set_thread_name("input|syslog|tcp|#{ip}:#{port}}")
        @codec.decode(data) do |event|
          event["host"] = ip
          syslog_relay(event)
          @output_queue << event
          end
        end
      end
    end
  end
  def run(output_queue)
    @logger.info("Starting syslog tcp listener", :address => "#{@host}:#{@port}")
    EventMachine::run do
      EventMachine::start_server @host, @port, SyslogRecv, {
        :queue => output_queue,
        :codec => @codec,
        :grok_filter => @grok_filter,
        :date_filter => @date_filter
      }
    end
  end
```

初次用 EventMachine，发现写法还蛮奇怪的。`start_server` 传递参数必须是 module 或者 class，然后变量只能随后通过额外的哈希传递进去。

木有看 CPP 的 EM 实现，看这里 foxbat 的实现，发现在 JRuby 里使用 Java 还真是简单啊：

```ruby
#!/usr/bin/env ruby
require "java"
require File.join(File.dirname(__FILE__), "netty-3.2.4.Final.jar")
require File.join(File.dirname(__FILE__), "syslogdecoder.jar")
java_import "com.loggly.syslog.SyslogDecoder"
java_import "org.jboss.netty.channel.SimpleChannelHandler"
java_import "org.jboss.netty.channel.ChannelPipelineFactory"
java_import "org.jboss.netty.channel.Channels"
java_import "org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory"
java_import "org.jboss.netty.bootstrap.ServerBootstrap"

class SyslogServerHandler < SimpleChannelHandler
  class << self
    include ChannelPipelineFactory
    def getPipeline
      return Channels.pipeline(SyslogDecoder.new, self.new)
    end # def getPipeline
  end # class << self

  def initialize
    super
  end # def initialize

  def messageReceived(context, event)
    e = event.getMessage.toString
    print('.')
  end # def messageReceived

  def exceptionCaught(context, exception)
    exception.getCause.printStackTrace
    exception.getChannel.close
  end # def exceptionCaught
end # class SyslogServerHandler

class RubySyslogServer
  def initialize(host, port)
    @factory = NioServerSocketChannelFactory.new(
      java.util.concurrent.Executors.newCachedThreadPool(),
      java.util.concurrent.Executors.newCachedThreadPool()
    )

    @bootstrap = ServerBootstrap.new(@factory)
    @bootstrap.setPipelineFactory(SyslogServerHandler)
    @bootstrap.setOption("child.tcpNoDelay", true);
    @bootstrap.setOption("child.keepAlive", true);

    @host = host
    @port = port
  end # def initialize

  def start
    address = java.net.InetSocketAddress.new(@host, @port)
    return @bootstrap.bind(address)
  end # def start

end # class SyslogServer

if __FILE__ == $0
  host = ARGV[0]
  port = ARGV[1].to_i
  RubySyslogServer.new(host, port).start
end
```

直接加载 jar 包，导入各种类。然后就能照样用了。
