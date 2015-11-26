---
layout: post
title: linux上获取本机ip的各种perl写法
date: 2011-09-20
category: linux
tags:
  - bash
  - perl
  - python
  - ruby
---

大家讨论使用 Gearman 做分布式处理时，各机需要注册一个独立的 job 作为信息反馈，但是为了方便，`Gearman::Worker` 脚本 `register_function` 代码又要通用，于是想到了使用各自的 ip 地址作为 job 命名~

那么怎么在 worker 脚本里获取本机 ip 作为 func 呢？

* 第一种办法，最简单的，调用 shell：

```perl
    $ip = `ifconfig eth0|grep -oE '([0-9]{1,3}\.?){4}'|head -n 1`;
```

注：这里输入是固定的，所以简单的 `[0-9]{1,3}` 了，如果是在 web 程序等地方验证 ip，需要更严谨！

或者

```perl
    $ip = `ifconfig eth0|awk -F: '/inet addr/{split($2,a," ");print a[1];exit}'`;
```

好吧，这样显得太不 perl 了，而且频繁的调用外部 shell 不太好

* 第二种：

```perl
    open FH,"ifconfig eth0|";
    while(<FH>){
        last unless /inet addr:((\d{1,3}\.?){4})/;
        print $1;
    }
```

看起来稍微 perl 了一些，虽然实质跟上面的调用 shell 和 grep 法是一样的。

* 第三种，更 perl 一点，纯粹读文件：

```perl
    open FH,'<','/etc/sysconfig/network-scripts/ifcfg-eth0';
    while(<FH>){
        next unless /IPADDR\s*=\s*(\S+)/;
    print $1;
    }
```

进一步的，如果不一定 rh 系，还要去读 `/etc/issue` ，确定网络配置文件到底是 `/etc/sysconfig/network-script/ifcfg-eth0` 还是 `/etc/network/interfaces` 还是其他，然后根据不同发行版写不同的处理方法……额，这是打算自己写模块么？

好吧，大家来充分体会 `CPAN` 的魅力，去 search 一下，找到一把 `Sys::HostIP`、`Sys::HostAddr`、`Net::Inetface` 等模块。

* 第四种：

```perl
    use Sys::HostAddr;
    my $interface = Sys::HostAddr->new(ipv => '4', interface => 'eth0');
    print $interface->main_ip;
```

不过进去看看pm文件，汗，这几个模块都是调用ifconfig命令，不过是根据发行版的不同进行封装而已。

还有办法么？还有，看

* 第五种：

```perl
    perl -MPOSIX -MSocket -e 'my $host = (uname)[1];print inet_ntoa(scalar gethostbyname($host))';
```

不过有童鞋说了，这个可能因为hostname的原因，导致获取的都是127.0.0.1……

那么最后还有一招。通过 `strace ifconfig` 命令可以看到，linux 实质是通过 ioctl 命令完成的网络接口 ip 获取。那么，我们也用 `ioctl` 就是了！

* 第六种如下：

```perl
    #!/usr/bin/perl
    use strict;
    use warnings;
    use Socket;
    require 'sys/ioctl.ph';
    sub get_ip_address($) {
        my $pack = pack("a*", shift);
        my $socket;
        socket($socket, AF_INET, SOCK_DGRAM, 0);
        ioctl($socket, SIOCGIFADDR(), $pack);
        return inet_ntoa(substr($pack,20,4));
    };
    print get_ip_address("eth0");
```

这样的好处，就是只调用了核心模块，在分发脚本时，不用连带安装其他模块。

_注_：这个其实是根据网上有的一个 py 的脚本修改的

* py版如下：

```python
    #!/usr/bin/python
    import socket
    import fcntl
    import struct
    def get_ip_address(ifname):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
                s.fileno(),
                0x8915,  # SIOCGIFADDR
                struct.pack('256s', ifname[:15])
        )[20:24])
    print get_ip_address('eth0')
```

_2012年12月19日增_：

为logstash的input/file.rb找到

* ruby版本的：

```ruby
    #!/usr/bin/ruby
    require 'socket'  
    SIOCGIFADDR    = 0x8915          # get PA address            
    def get_ip_address(iface)  
      begin  
        sock = UDPSocket.new  
        buf = [iface,""].pack('a16h16')  
        sock.ioctl(SIOCGIFADDR, buf);  
        sock.close  
        buf[20..24].unpack("CCCC").join(".")  
      rescue  
        nil  
      end  
    end  
    if $0 == __FILE__  
      puts get_ip_address('eth0')  
    end  
```

不过看puppet里还是用ifconfig的方法。
