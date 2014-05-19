---
layout: default
title: 学习记录
group: navigation
---
<div class="row">
之前经常看到一些稀奇古怪又很好玩的东西，转头就忘了，从今天开始，在这里记录一些工作用得上用不上能用得上不用用得上的名词，免得以后再忘了~~不定期更新。<br />
2014-05-19<br />
dashing: 基于 sinatra 和 batman.js 做的界面，可以拖动面板到页面其他位置，有利于监控UI定制。<a href="http://shopify.github.io/dashing/">http://shopify.github.io/dashing/</a><br />
APM: 主要就是 java 写的业务系统的数据收集。目前在 github 上看到两个。一个是 Splunk 的 <a href="https://github.com/damiendallimore/SplunkJavaAgent">Agent</a>，一个是韩国人写的 <a href="https://github.com/owlab/fresto">fresto</a>。<br />
<br />
2014-05-15<br />
packetbeat: 通过 pcap 抓包，然后导入 elasticsearch 通过 kibana 展示分析结果。<br />
Net::Frame 模块: 可以通过 pcap/dnet 修改来源 IP 构建 IP 包发送出去。<br />
2013-10-29<br />
docker: lxc 的简洁接口使用，可以有类似git commit一样的镜像管理，比 Vagrant 更加方便。<br />
Serf: Golang 的自动发现和管理<a href="http://www.serfdom.io/">http://www.serfdom.io/</a>。<br />
2013-04-01<br />
Batman.js: A client-side framework for Rails developers with CoffeeScript<a href="http://batmanjs.org/">http://batmanjs.org/</a><br />
2013-03-27<br />
Haml: Ruby模板系统<a href="http://haml.info/docs/yardoc/">http://haml.info/docs/yardoc/</a><br />
2013-03-18<br />
HAR(HTTP Archive)：规范中文版<a href="http://weizhifeng.net/har-12-spec-chinese-edtion.html">http://weizhifeng.net/har-12-spec-chinese-edtion.html</a><br />
2013-02-23<br />
boomerang: 网页性能监控工具。地址: <a href="http://lognormal.github.com/bomerang/doc/howtos/index.html">github.com/lognormal/boomerang</a><br />
2012-10-06<br />
proclet: 一个类foreman的简约版supervisor。地址：<a href="http://search.cpan.org/~kazeburo/Proclet-0.14/bin/proclet">http://search.cpan.org/~kazeburo/Proclet-0.14/bin/proclet</a><br />
2012-05-31<br />
RRDTOOL implementation of Aberrant Behavior Detection: 一个RRD的异常预警patch，说明地址：<a href="http://cricket.sourceforge.net/aberrant/rrd_hw.htm">http://cricket.sourceforge.net/aberrant/rrd_hw.htm</a>，其原理说明见：<a href="http://static.usenix.org/events/lisa00/full_papers/brutlag/brutlag_html/">http://static.usenix.org/events/lisa00/full_papers/brutlag/brutlag_html/</a><br />
2012-05-14<br />
node-perl: node.js的embed perl工具，详见<a href="https://github.com/hideo55/node-perl">https://github.com/hideo55/node-perl</a>，同理还有MyPerl和apache/nginx的embedded perl模块。<br />
fpm: 全名是Effing Package Management，我汗==!详见<a href="https://github.com/jordansissel/fpm">https://github.com/jordansissel/fpm</a><br />
ubic: perl的服务进程托管工具，详见<a href="https://metacpan.org/module/ubic">https://metacpan.org/module/ubic</a><br />
2012-03-16<br />
logstash：开源的集中式日志收集和分析展示平台，使用JRuby编写，结合了Lucene，RabbitMQ，NodeJS等多种开源项目。详见<a href="http://logstash.net">http://logstash.net</a><br />
2011-11-14<br />
convirt：开源的xen集群管理平台，详见<a href="http://www.convirture.com">http://www.convirture.com</a><br />
ganeti：开源的xen/kvm集群管理平台，详见<a href="http://code.google.com/p/ganeti">http://code.google.com/p/ganeti</a><br />
OpenNebula：开源的xen/kvm/vmware集群管理平台，详见<a href="http://www.opennebula.org">http://www.opennebula.org</a><br />
<hr />
2011-6-14<br />
dnsdusty：perl写的bind9页面配置程序，详见<a href="https://fedorahosted.org/dnsdusty/">https://fedorahosted.org/dnsdusty</a><br />
nictool：perl写的bind和tinydns页面配置程序，详见<a href="http://www.nictool.com">http://www.nictool.com</a><br />
JMX::Jmx4Perl：perl的jmx接口，读取java状态。<br />
<hr />
2011-4-20<br />
ipmitool：通过ipmi协议远程控制服务器bmc芯片，详见<a href="http://www.ibm.com/developerworks/cn/linux/l-ipmi/">http://www.ibm.com/developerworks/cn/linux/l-ipmi/</a><br />
<hr />
2011-4-13<br />
perl的DB_File模块和tie的使用<br />
<hr />
2011-3-7<br />
多nagios展现平台：<a href="http://www.thruk.org">http://www.thruk.org</a><br />
check_mk，号称性能比nrpe和snmp都好：<a href="http://mathias-kettner.de">http://mathias-kettner.de</a>但是只支持python编写插件。注意这里可以在插件里处理exit code<br />
<hr />
2011-3-1<br />
SNMP企业代码：<a href="http://www.iana.org/assignments/enterprise-numbers">http://www.iana.org/assignments/enterprise-numbers</a><br />
<hr />
2011-2-21<br />
两篇来自OpenSUSE官网的指南。<br />
<a href="http://doc.opensuse.org/products/draft/SLES/SLES-tuning">http://doc.opensuse.org/products/draft/SLES/SLES-tuning</a><br />
<a href="http://doc.opensuse.org/products/draft/openSUSE_114/opensuse-tuning">http://doc.opensuse.org/products/draft/openSUSE_114/opensuse-tuning</a><br />
两篇指南从目录来看，有很多相同的地方。不过还是可以对照看看。<br />
周六的时候发现的，结果周天听说就被GFW过，吓杀我也~~<br />
然后去RedHat官网的docs上看了看，发现RedHat吝啬的很，全是企业版的安装使用说明，CentOS的更加简陋……<br />
另两篇来自IBM官网的红宝书。<br />
<a href="http://www.redbooks.ibm.com/redpapers/pdfs/redp3861.pdf">http://www.redbooks.ibm.com/redpapers/pdfs/redp3861.pdf</a><br />
<a href="http://www.redbooks.ibm.com/redpapers/pdfs/redp4285.pdf">http://www.redbooks.ibm.com/redpapers/pdfs/redp4285.pdf</a><br />
一个明确说的是redhat，但版本及其老，五年前就没更新了。另一个概述linux，08年更新。<br />
<hr />
2011-1-28<br />
xen的P2V迁移。<br />
<hr />
2011-1-12<br />
DRBD：分布式块设备复制软件。官网：<a href="http://www.drbd.org/">http://www.drbd.org</a><br />
从2.6.33开始，DRBD进入linux主线kernel。用来实现集群数据的高可用。<br />
常见于MySQL集群应用，可用性高于普通的replication。算是NetApp的mirror的“穷人”版本吧？<br />
看到新浪研发中心博客中有使用DRBD的HA方案解决mooseFS的master单点问题的测试。<br />
<hr />
2011-1-11<br />
<br />
spread：分布式分组消息系统。官网：<a href="http://spread.org/">http://spread.org</a><br />
        可以用来处理大规模集群的应用日志;(Fedora的spread-logging)<br />
        可以用来完成SQL的replication;(RepDB项目，试验期，无视)<br />
        可以用来完成数据同步(zope项目，不懂python，无视)<br />
        最后，只要能发送消息，那么也可以完成对集群的运维管理。(自己瞎想，不知道有没有现成的)<br />
<br />
mogileFS：分布式文件系统，memcached的同门师兄弟。官网：<a href="http://www.danga.com/mogilefs/">http://www.danga.com/mogilefs</a><br />
        包含有性能不亚于lighttpd的web服务器perbal，提供web、代理、负载均衡、缓存等多种功能;<br />
        包含有跨平台任务分发框架gearman，可以用于分布式计算的map-reduce调度，也可以用于一般的日志分析处理。<br />
        提供直接的nginx-mogilefs-module，也可以通过另外的fuse脚本mount使用。<br />
        适用于增量型小图片存储。<br />
        有时间深入学习perl再看。<br />
<br />
HAproxy：4/7层负载均衡，功能比较完善。但公认的测评报告不多，到底能用到什么程度呢？官网：http://haproxy.1wt.eu/<br />
<br />
Varnish：内存型反向代理缓存软件。比squid更充分的利用硬件和操作系统的新功能。不过对大容量缓存性能下降较快。<br />
<br />
Apache Traffic Server：雅虎2009年转交给apache基金会的顶级开源项目，同样是缓存软件。<br />
<br />
Squid3.2：从3.2开始，squid终于支持多CPU了，一定要测试一下。<br />
<br />
puppet：轻量级集中式配置管理软件。官网：<a href="http://www.puppetlabs.com/">http://www.puppetlabs.com/</a><br />
        中文wiki：<a href="http://puppet.wikidot.com/">http://puppet.wikidot.com/</a><br />
        puppet北京用户组博客：<a href="http://www.comeonsa.com">http://www.comeonsa.com/</a><br />
        从系统镜像分发到服务状态检测，大型数据中心运维的一揽子计划~<br />
</div><br />

