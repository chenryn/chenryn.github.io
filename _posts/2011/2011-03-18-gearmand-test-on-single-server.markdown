---
layout: post
title: gearman单机试验
date: 2011-03-18
category: perl
tags:
  - gearman
---

想把前端缓存几十台服务器的访问日志数据计入数据库中，以便核算各频道带宽。按照一般流量统计的惯例，在服务器上设定crontab每5分钟rotate一次access.log。但是想到一个问题——当A服务器select了数据库里的数据但还没来得及update时，B服务器也开始执行任务select数据来了，最后的结果就不准确了——我相信这个问题对coder来说很低级，不过我是op，搞不来……
不过op有op的思路——咱把所有的数据汇总由一台服务器来写数据库。考虑scp或者rsync可能会出现的各种未知失败（这个失败太普遍了，相信所有的op都有体会），打算试试gearman。
gearman出现的本意，是由jobserver来派发client的jobs到workers完成，比如张宴提到金山用它来分发上传图片的缩略裁剪（这也正是LiveJourna发明gearman的初始用途）；比如TimYang提到用它来分发监控任务；OSCON2009的文档上，还提到了搜索引擎、分布式文件系统、map/reduce、日志分析、mysql集群处理等多种应用。
其中关于日志分析的结构图如下：
<a href="http://chenlinux.com/wp-content/uploads/2011/03/gearman4log.jpg"><img class="alignnone size-medium wp-image-2326" title="gearman4log" src="http://chenlinux.com/wp-content/uploads/2011/03/1-300x293.jpg" alt="" width="300" height="293" /></a>
好了。上面都是虚的。现在开始做实验。
下载gearman的c语言版，毕竟单纯就为了记录下带宽值的话，没必要下perl版的来折腾——注意，和memcached一样，gearman也采用了libevent，所以必须先安好libevent：
{% highlight bash %}
wget http://launchpad.net/gearmand/trunk/0.14/+download/gearmand-0.14.tar.gz
tar zxvf gearmand-0.14
cd !$
./configure && make && make install
{% endhighlight %}
默认会采用sqlite存储持久化队列。如果觉得memcached什么的更有爱，也可以--with。
安装完成后，会在/usr/local/bin下生成gearman和gearmand两个文件，前一个是worker和client共用的；后一个是jobserver。
首先要启动jobserver：
gearmand -d -p 7003
然后开启一个client：
echo 'test' | gearman -h 127.0.0.1 -p 7003 -f testwork
资料都说7003是gearman的默认端口，但C版的必须明确定义才行。
这个时候，可以telnet 127.0.0.1 7003上去，输入status看看了，上面显示“1 0 0”，表示有一个请求在队列中等待执行了。
然后注册一个worker：
gearman -n -w -f testwork -- ls -lh
资料也都没有要使用-n参数。但如果不用这个，worker会在接收执行完队列中的第一个任务后就主动退出了！
ok，现在执行结果出来了。在client端（因为单机执行，其实就是运行client命令的ssh窗口），显示出来了一串文件信息，就是worker端的ls -lh结果。
然后重新注册worker，以测试client传递的内容能被worker正确处理：
gearman -n -w -f testwork | awk '{print $0}'
嗯？worker端还是没有反应啊？切到client来，发现client这边显示了test！难道是标准输出就是用来返回给client的？那试试别的命令试试吧。
重新注册worker：
gearman -n -w -f testwork | awk '{system("touch /tmp/"$0}'
这时候也可以telnet上去看看status，会显示“0 0 1”，表示有一个注册在jobserver上的worker；
然后重新发起client：
echo 'test' | gearman -h 127.0.0.1 -p 7003 -f testwork
在到/tmp下一看，确实出现了/tmp/test文件了~~
不过，如何确定这个/tmp/test是worker生成的，而不是client呢（单机测试就是郁闷啊……）
修改一下worker：
gearman -n -w -f testwork | awk '{system("sleep 100;touch /tmp/"$0}'
重新发起client，因为有sleep 100在，这次client没有立刻退出，但为了测试需要，按下Ctrl+C，终止client的运行，以确保命令不会是由client执行的（更确保一点，可以退出ssh会话）。
切换到/tmp/目录下，用stat命令查看/tmp/test文件的CTIME——目前还是上一次试验时的生成时间。
这时候telnet看status，显示是“1 0 1”，表示一个job正在运行。
再过一会儿，stat看，发现/tmp/test的CTIME突然变成一个新的时间了。可见touch命令确实是由worker执行的。
