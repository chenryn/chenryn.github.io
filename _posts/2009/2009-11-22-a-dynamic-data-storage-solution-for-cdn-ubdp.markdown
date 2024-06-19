---
layout: post
theme:
  name: twitter
title: 一种CDN中的动态数据存储方案——UbDP
date: 2009-11-22
category: CDN
---

上回百度到这篇文章，于是上维普下载了来看，为方便阅读，贴在这里。

原文出处《计算机应用》2008年8月第28卷第8期：

<hr /><strong>一种CDN中的动态数据存储方案——UbDP
</strong>汤迪斌，王劲林，倪宏
(1．中国科学院研究生院，北京100039；2．中国科学院声学研究所国家网络新媒体工程技术研究中心，北京100080)
(<a href="mailto:tangdihin@gmail.com">tangdihin@gmail.com</a>)

<strong>摘要：</strong>CDN对于动态Web应用的加速通常采用数据缓存或复制技术。针对论坛、博客服务提供商等为注册用户提供个人信息发布平台的网站，提出了一种基于用户的数据分割方法：将数据按所属注册用户进行分割，分布到离该用户最近的数据库系统中。将数据库UID操作分散到多个数据库系统，消除了单个数据库系统的I／O瓶颈。
<strong>关键词：</strong>内容分发网络；分布式数据库；数据缓存；动态Web应用
<strong>中图分类号：TP3l1.133.1  文献标志码：A</strong>

0 引言
尽管网络带宽和服务器性能在不断改善，用户访问迟延过大一直是Web应用的一个重要问题。随着流媒体的出现，迟延问题变得更加严重。导致Internet上内容传送迟延过大的原因主要有两个：1)缺乏对Internet的全局管理；2)有限的网络带宽和服务器资源总是跟不上网络负载增长的脚步。解决这个性能问题的基本办法就是将内容移到离最终用户较近的边缘服务器上。内容分发网络(Content Delivery Network，CDN)正是采用了这个办法，减小了访问迟延，提高了数据传输速率。目前CDN主要应用于静态内容的缓存，如静态页面、图片、音视频文件等。对于动态内容的缓存尚处在研究当中，目前主要有边缘计算(Edge Computing)[5,6]、数据库复制(Database Replication)[7,8]、内容感知数据缓存(Content-Aware Cache，CAC)[9-11]、内容无关数据缓存(Content-Blind Cache，CBC)[12,13]四种研究方向。文献[14]的研究表明复制和缓存方法的选择很大程度上依赖于具体的应用，没有一种技术能很好地适用各种Web应用。对于论坛类网站，内容无关缓存方案性能最佳，而对于Amazon类的电子商务网站，数据库复制才是最好的选择。

论坛和博客服务提供商网站的主要特点是：网站内容由大量注册用户产生，每个用户只能添加、修改和删除属于自己的内容，所以对数据库的写操作(UID、Update、Insert and Delete)来源于处于不同位置的用户。本文针对这类为注册用户提供个人信息发布的网站，提出了一种内容分发网络中基于用户的数据分割方法(User-based Data Partition，UbDP)方案：将数据按所属注册用户进行分割，分布到离该用户最近的数据库系统中。
l 内容缓存和内容复制技术
动态网站的普及，驱使CDN和数据库研究组织都在寻找适用于动态内容的先进缓存技术。文献总结了目前主要的四种动态内容缓存和复制技术方案。
边缘计算就是将生成动态页面的代码如PHP代码、ASP代码分发到合适的边缘服务器(Edge Server，ES)上，数据还是保存在内容提供商的原始服务器(Origin Server，OS)上。Es根据Session(用来标识不同的用户会话)、OS上的数据等信息为每个用户生成动态页面。这类方法的优点是结构简单，不需要对原有CDN结构做出调整。缺点是每个数据库查询都需要到0S上执行，增加了迟延，且0S很可能成为性能瓶颈。
数据库复制技术为了解决边缘计算的迟延和数据库瓶颈问题，将数据库也复制到多个ES上，这样ES就能在本地生成动态页面，较大地减小了用户迟延。但是，为了维护数据的一致性，UID操作需要在所有数据库服务器上执行一遍，这会增加大量额外的网络流量和服务器处理开销。

相对于数据库复制技术在ES中复制整个数据库，CAC方案中ES只缓存数据库的一部分。每次查询数据库时，Es都先检查本地数据库中的数据是否足够应答此次查询请求，这个过程称为查询包含检查。如果本地数据足够，则查询请求在本地执行；否则，请求被转发到0S上，ES会缓存查询结果以备后用。这种方案的主要缺点是查询包含检查的计算复杂度太高。
为了降低查询包含检查的计算复杂度，CBC方案得到了应用：ES中根本不运行数据库软件，而只是单独缓存各个数据库查询的结果。因为并不合并各缓存的查询结果，只有当查询语句完全相同时才算缓存命中，所以查询包含检查的计算复杂度大大降低。
以上四种方案都有一个共同的缺点，即所有的UID操作都需要在OS上执行，然后通过一定的策略更新ES上的缓存。这样，在数据库更新相当频繁的应用中，0S上的数据库势必成为系统的性能瓶颈。本文提出的UbDP很好地将UID操作分散到了多个数据库系统，解决了数据库瓶颈问题。
2 基于用户的数据分割
基于用户的数据分割方案应用于传统的CDN架构之上，增加了分布式数据库系统用于存储动态数据，而不改变CDN中原服务器的功能。
<strong>2.1系统架构</strong>

<a href="http://photo.blog.sina.com.cn/showpic.html#blogid=62d80b5e0100fpe8&amp;url=http://static12.photo.sina.com.cn/orignal/62d80b5et727ea2f919eb&amp;690"><img title="一种CDN中的动态数据存储方案——UbDP" src="http://static12.photo.sina.com.cn/bmiddle/62d80b5et727ea2f919eb&amp;690" alt="一种CDN中的动态数据存储方案——UbDP" /></a>

图1 UbDP系统架构

如图1所示。将CDN中的ES按照所在位置划分为有限的多个逻辑区域Region1、Region2、…RegionN，在每个区域内布置一套数据库系统，该数据库系统可以是单台数据库服务器，也可以是由多台数据库服务器组成的Master、Slave结构。数据库中除了存储用户数据外，还维护了用户和其主数据库(Home Database，HDB)的对应关系。每个区域还有一个数据库查询代理(Query Agent，QA)，接收所有查询请求，根据查询请求类型进行不同的数据库操作。
ES接收到用户HTTP请求后，根据需要向QA发送数据库查询请求，QA从自身缓存或后台数据库取得数据返回给ES，ES生成返回页面。
全局负载均衡器(Global Server Load Balancing，GSLB)的目的是在整个网络范围内，将用户请求定向到最近的节点。因此，就近性判断是其主要功能。

<strong>2.2数据库查询代理</strong>

<a href="http://photo.blog.sina.com.cn/showpic.html#blogid=62d80b5e0100fpe8&amp;url=http://static2.photo.sina.com.cn/orignal/62d80b5et78f27edbd2f1&amp;690"><img title="一种CDN中的动态数据存储方案——UbDP" src="http://static2.photo.sina.com.cn/bmiddle/62d80b5et78f27edbd2f1&amp;690" alt="一种CDN中的动态数据存储方案——UbDP" /></a>

如图2所示，数据库查询代理QA由查询接口、查询分类器、单库查询缓存和多库查询代理组成。
将数据库查询分为三类：第一类为UID操作；第二类只需要查询一个用户的数据，称为单库查询，包括获取用户信息、获取文章内容等，如：
Q1：SELECT name FROM user WHERE userId = 2
Q2：SELECT title FROM post WHERE id = 3 and userId = 2;
Q1从用户表中获取id为2的用户名；Q2从博客文章表中获取用户2的id为3的文章标题。
第三类查询需要同时获取多个用户的数据，称为多库查询，包括用户积分榜、最新博客文章、博客搜索等，如：
Q3：SELECT userId FROM user ORDER BY score DESC LIMIT 0，10
Q4：SELECT postId FROM blog_index WHERE keyword="旅游"
Q3获取积分最高的10个用户id；Q4从索引表中搜索包含关键字“旅游”的所有博客文章。
查询分类器接收到非UID查询请求后，根据是否包含“userld=”查询条件判断查询所属分类(如果包含“userld=”则是单库查询，否则为多库查询)，将请求转发给单库查询缓存或多库查询代理处理。单库查询缓存采用文献[13]中所述的CBC缓存方法，没有命中缓存时的处理流程如下图3所示，先解析出该请求涉及的用户，然后向同区域内的数据库获取该用户的HDB，将查询请求发往HDB，缓存并返回查询结果。

<a href="http://photo.blog.sina.com.cn/showpic.html#blogid=62d80b5e0100fpe8&amp;url=http://static16.photo.sina.com.cn/orignal/62d80b5et78f27fa6784f&amp;690"><img title="一种CDN中的动态数据存储方案——UbDP" src="http://static16.photo.sina.com.cn/bmiddle/62d80b5et78f27fa6784f&amp;690" alt="一种CDN中的动态数据存储方案——UbDP" /></a>

多库查询代理内部也有一个CBC缓存模块，没有命中缓存时，将查询请求广播到所有数据库系统，综合各数据库查询结果，缓存并返回最终查询结果。为了提高响应速度，对于搜索类不需要对结果进行排序的多库查询，只需一个数据库返回结果，多库查询代理可以立即将结果返回给ES。
<strong>2.3主数据库选择策略</strong>
HDB的选择依赖于用户所在的位置，当用户所在位置发生变化时，系统为他选择的HDB也会变化。
1)设置用户注册或第一次登录时所使用ES所在区域为该用户的主区域(Home Region，HR)，HR内的数据库为该用户的HDB；HDB将该用户的HDB更新情况广播给所有数据库；
2)HDB记录所有它负责用户UID操作的来源区域；如果发现对于某个用户，上一个时问片断内来自某区域的UID操作多于本区域，则可以判断该用户暂时或永久迁移到了新区域，设置新区域内的数据库为该用户的HDB；
3)将该用户的最新信息同步到新HDB；此过程中，为了避免冲突，需要将该用户数据写锁定，不允许用户更新：选择用户离线时更新其HDB，可以减少写锁定带来的影响；
4)将该用户HDB更新情况广播到所有数据库。根据CDN的请求路由原则，用户请求总是被转发到最合适的Es。理想情况下，从同一个位置发起的多次请求，都会被转发到离用户最近的同一个ES上，称为理想ES。考虑到网络拥塞和ES的负载情况，大多数同一个位置发起的多次请求都会被转发到理想ES同一区域内的ES上。所以只有当用户所在位置发生大范围变动时，才需要更新HDB。实际应用中用户并不会经常性地变化所在区域，所以HDB变化的可能性很小，为用户提供服务的ES通常会和HDB位于网络迟延较小的同一区域内。由于将数据库的读写操作都移到了离用户较近的边缘服务器上，用户迟延大大减小。
3 性能分析
本文用RUBBoS对UbDP和数据集中存储内容无关缓存系统的性能进行了比较。RUBBoS是一个模拟了slashdot.org的基准测试程序，它主要包含了3个数据库表，分别存储了5000000个用户、6000篇文章和200000条评论。我们使用了RUBBoS的PHP实现来进行我们的试验。我们使用RUBBoS的ClientEmulator模拟用户会话来访问网站，用户的平均思考时间为7s，且符合TPC-W标准。边缘服务器和数据库服务器都是2.8GHzCPU，1GB内存，边缘服务器中使用Apache2.2.3和PHP5.2.4，数据库软件为MySQL5.0.22。用NISTNET来模拟广域网环境，图4中实线连接带宽为90Mbps，时延为10ms，表示网络节点在同一个区域内；虚线连接带宽为50Mbps，时延为100ms，表示网络节点位于不同的区域。试验方法是测量不同负载情况下的用户迟延即用户发出请求到收到回复之间的时间差。

<a href="http://photo.blog.sina.com.cn/showpic.html#blogid=62d80b5e0100fpe8&amp;url=http://static8.photo.sina.com.cn/orignal/62d80b5et78f29205e7a7&amp;690"><img title="一种CDN中的动态数据存储方案——UbDP" src="http://static8.photo.sina.com.cn/bmiddle/62d80b5et78f29205e7a7&amp;690" alt="一种CDN中的动态数据存储方案——UbDP" /></a>

图5 用户只发表评论的性能结果

当用户只进行发表评论操作，即用户的每个请求都会产生数据库UID操作时，测试结果如图5所示。如果认为大于5000ms的用户等待时间是不可接受的，则采用UbDP后，系统的UID容量增加了约40％。系统容量并没有随着服务器的增加而线性增加，原因是：1)没有增加边缘服务器ES的数量，系统整体性能部分受限于ES的计算能力；2)采用UbDP引入了额外的数据库查询负载，每个UID操作前需要执行一个数据库读操作，导致了负载较低时，UbDP的迟延甚至大于内容无关缓存系统。
当用户进行普通浏览时(10％的用户会发表评论，其他用户只是浏览)，测试结果如图6所示。在并发用户会话数较小(140以下)时，采用UbDP后平均用户迟延略小于内容无关缓存系统，这是由于UbDP虽然引入了一次额外的数据库查询，但增加的额外查询是在网络迟延较小的本区域数据库上执行的，且原查询也有约一半的几率在本区域数据库上执行。随着并发用户会话数的增加，UbDP由于额外的数据库查询请求，更早进入满负载状态，用户平均迟延逐渐大于内容无关缓存系统。

<a href="http://photo.blog.sina.com.cn/showpic.html#blogid=62d80b5e0100fpe8&amp;url=http://static5.photo.sina.com.cn/orignal/62d80b5et78f29e83c744&amp;690"><img title="一种CDN中的动态数据存储方案——UbDP" src="http://static5.photo.sina.com.cn/bmiddle/62d80b5et78f29e83c744&amp;690" alt="一种CDN中的动态数据存储方案——UbDP" /></a>

图6 用户普通浏览的性能结果

为了减少额外数据库查询带来的影响，町以在所有ES上增加一个CBC缓存模块，用来缓存用户和HDB的对应关系，CBC接近90％的缓存命中率较大提高了UbDP系统的总体性能(如图6虚线所示UbDP+ES-CBC)。
4 结语
针对论坛和博客服务提供商之类为注册用户提供个人信息发布平台的网站，本文提出了一种内容分发网络中用户分割的分布式数据库系统，通过将不同用户的数据分布到不同的数据库服务器上，有效地将数据库UID操作分散到了多个数据库上，系统的可扩展性大大提高；其代价是增加了额外的读数据库操作，使得在高负载(并发用户数大于140)时，系统性能略低于内容无关缓存系统，但通过在ES上增加CBC模块可以有效减小这一影响。
对于所有数据库表都直接或间接包含某个外键的应用场合，本文所述数据分割方法都适用。

<strong>参考文献：</strong>

[5]RABINOVICH M,ZHEN XIAO,AGARWAL A. Computing on the edge: A platform for replicating internet applications[C]//Proceedings of the Eighth International Workshop on Web Content Caching and Distribution.Norwell,MA,USA:Kluwer Academic Publishers,2004:57-77;
[6]RABINOVICH M,ZHEN XIAO,DOUGLIS F,et al. Moving edge side includes to the real edge-the clients[C]//Proceedings of the 4th conference on USENIX Symposium on Internet Technologies and Systems.Berkeley,CA,USA:USENIX Association.2003:12;
[7]CECCHET E.C-JDBC:a middleware framework for database clustering[J].IEEE Data Engineering Bulletin,2004,27(2):19-26;
[8]PLATTNER C,ALONSO G.Ganymed:Scalable replication for transactional Web applications[C]//Proceedings of the 5th ACM/IFIP/USENIX International Conference on Middleware.New York,NY,USA:Springer-Verlag,2004:155-174;
[9]AMIRI K,PARK S,TEWARI R,et al. DBProxy:A dynamic data cache for Web applications[C]//Proceedings of 19th Internation Conference on Data Engineering.Bangalore,India:IEEE Computer Society,2003:821-831;
[10]BORNHD C,ALTINEL M,MOHAN C，et al. Adaptive database caching with DBCache[J].IEEE Data Engineering Bulletin,2004,27(2):11-18.
[11]BUCHHLZ T,HOCHSTATTER I,LINNHOFFPOPIEN C.A profit maximizing distribution strategy for context-aware services[C]//Proceedings of Second IEEE International Workshop on Mobile Commerce and Services(WMCS'05).Los Alamitos,USA:IEEE Computer Society,2005:144-153;
[12]OLSTON C,MANJHI A,GARROD C,et al. A sealability service for dynamic Web applications[C]//Proceedings of the Conference on Innovative Data Systems Research(CIDR).Asilomar,CA,USA:ACM Press,2005:56-69;
[13]SIVASUBRAMANIAN S,PIERRE G,VAN STEEN M,et al. GlobeCBC:Content-blind result caching for dynamic Web applications[R].Amsterdam,The Netherlands:Vrije Universiteit,2006;
[14]SIVASUBRAMANIAN S,PIERRE G,VAN STEEN M,ALONSO G.Analysis of caching and replication strategies for Web applications[J].IEEE Internet Computing,2007,11(1):60-66;
[15]Rice University,INRIA.RUBBoS:Bulletin Board Benchmark[EB/OL].[2008-01-21]. <a href="http://jmb.objeetWeb.org/rnbbos.html">http://jmb.objeetWeb.org/rnbbos.html</a>;
[16]National Institute of Standards and Technology.NIST net home page[EB/OL].[2008-01-21].http://www-x.antd.nist.gov/nistnet/;

