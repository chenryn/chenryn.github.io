---
layout: post
title: OMD系列(三)shinken的discovery配置与运行
date: 2011-12-20
category: monitor
tags:
  - nagios
  - shinken
---

上篇说到OMD的可以通过omd config选择core，有nagios和shinken两个选项。shinken是一个完全重写的监控系统，但是在外部接口上，又是nagios-like的，甚至可以单纯的只用shinken的WebUI给nagios使。所以OMD作为nagios周边的项目，也就把shinken加入到core选项里了。
不过经过试验发现，虽然omd的rpm是针对centos5.5的，代码中调用的有些命令版本却比较高，比如nmap命令使用了--traceroute选项，查ChangeLog发现是4.76版才加上的，而centos5上面的还是4.11版，所以要重新安装：

```bash
wget http://nmap.org/dist/nmap-5.51-1.x86_64.rpm
yum remove nmap
yum install --nogpgcheck nmap-5.51-1.x86_64.rpm
```

又比如python，centos5默认安装的是2.4版，而nmap_parser中调用了2.5版才有的xml.tree.elementtree模块，所以也要升级。

```bash
wget http://www.python.org/ftp/python/2.7.2/Python-2.7.2.tgz
tar zxvf Python-2.7.2.tgz
cd Python-2.7.2
./configure --prefix=/usr/local/python2.7
make -j
make install
rm -f /usr/bin/python
#alternatives命令之前博客有介绍，其实就是文雅一点的替你做软连接和版本路径记录。
#切换的时候用alternatives --config python命令选择就可以了。
alternatives --install /usr/bin/python python /usr/local/python2.7/bin/python 1000
alternatives --install /usr/bin/python python /usr/bin/python2.4 500
wget http://peak.telecommunity.com/dist/ez_setup.py
python ez_setup.py
/usr/local/python2.7/bin/easy_install ElementTree
```

然后就可以试试nmap_discovery_runner.py和vmware_discovery_runner.py了。
命令行方式运行如下：

```bash
/opt/omd/sites/dyxmonitor/lib/shinken/libexec/nmap_discovery_runner.py -t 127.0.0.1
Got our target ['127.0.0.1']
propose a tmppath /tmp/tmppTYexK
Launching command, sudo nmap 127.0.0.1 -T4 -O --traceroute -oX /tmp/tmppTYexK
Try to communicate
Got it ('\nStarting Nmap 5.51 ( http://nmap.org ) at 2011-12-20 15:45 CST\nNmap scan report for localhost (127.0.0.1)\nHost is up (0.000030s latency).\nNot shown: 995 closed ports\nPORT     STATE SERVICE\n22/tcp   open  ssh\n80/tcp   open  http\n111/tcp  open  rpcbind\n631/tcp  open  ipp\n3306/tcp open  mysql\nDevice type: general purpose\nRunning: Linux 2.6.X\nOS details: Linux 2.6.15 - 2.6.31\nNetwork Distance: 0 hops\n\nOS detection performed. Please report any incorrect results at http://nmap.org/submit/ .\nNmap done: 1 IP address (1 host up) scanned in 2.05 seconds\n', '')
Can be ('Linux', '2.6.X', '100')
Try to match ('Linux', '2.6.X')
localhost::isup=1
localhost::os=linux
localhost::osversion=2.6.X
localhost::macvendor=
localhost::openports=22,80,111,631,3306
localhost::fqdn=localhost
localhost::ip=127.0.0.1
```

从输出中可以看到使用的nmap运行参数，主要是-O扫描操作系统，-T4指定快速，-oX指定输出成xml，然后用python去解析xml文件就是了。
然后运行omd的命令：

```bash
su - monitor
mkdir -p etc/shinken/objects/discovery
shinken-discovery -o /omd/sites/monitor/etc/shinken/objects/discovery -r nmap -c /omd/sites/monitor/etc/shinken/shinken-discovery.d/discovery.cfg
```

然后发现新错误：在import shinken和multiprocessing的时候有问题。
因为etc/environment中需要定义PYTHONPATH=/omd/sites/monitor/lib/python:/omd/sites/monitor/lib/shinken:/usr/local/py2.7/lib/python2.7
而且，因为在/omd/sites/monitor/lib/python中有multiprocessing-2.6.2.1-py2.4-linux-x86_64.egg的存在，所以导致python2.7加载py2.4的multiprocessing失败，删除掉这个目录后，让python自动加载python2.7/lib下的multiprocessing，就可以了——当然，需要先easy_install multiprocessing才有。
等一会，在objects/discovery目录下给每个live的ip创建了一个文件夹，里面是host和service的cfg配置——但是因为~/bin/shinken-discovery脚本里的写法比较简单，生成的cfg里直接指定了template就是generic-host/service，然后除了description、command和host_name之外啥都木有……所以必须提前自己定义好一个模板。
OMD的监控配置文件指定位置是~/etc/nagios/conf.d/，所以扫描之后，还需要整合cfg到这个目录下。
<hr>
最后，shinken里有bottle框架的一个webui，但是我一直没找到如何运行……shinken-specific.d/module_webui.cfg里倒是有module定义：

```bash
define module{
    module_name      WebUI
    module_type      webui
    host             0.0.0.0       ; mean all interfaces
    port             7767
    auth_secret      CHANGE_ME
    modules          Apache_passwd
}
define module{
    module_name      Apache_passwd
    module_type      passwd_webui
    passwd           /omd/sites/dyxmonitor/etc/htpasswd
}
```

但是启动后没有看到7767端口，也没有看到任何报错——这是最让我郁闷的一点，折腾三天，全部排错都靠strace而木有log。。。
所以最后还是用另一个nagios界面，trunk来启动web。trunk是一个基于perl的catalyst框架完成的页面。而omd自带了一个不小的perl5lib……这里又需要注意了：

1. OMD安装时，会自动配置一个$PERL5LIB变量，但是不知道为啥会把**/x86_64-linux-thread-multi记成**/x86_64-linux，所以需要在~/etc/environment中自己重新写一次PERL5LIB。
2. 因为centos5.4自带的perl版本是5.8.8；如果像我这样自己又另外安装了更高版本的perl，比如5.14.2，那么omd自带的这些perl5lib会有"undefined symbol: Perl_Gthr_key_ptr"的错误。所以老老实实用perl5.8.8好了……

说老实话，觉得trunk跟classic nagios的页面没什么不同……
