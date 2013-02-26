---    
layout: post    
title: 动态页面正文部分中文乱码排障一例    
date: 2010-06-26    
category: web
tags:
  - apache
  - nginx
  - resin
---    
    
公司网站一部分动态页面，早先使用apache+resin的架构运行，考虑到高并发访问下的响应性能问题，在前不久逐步开始用nginx替换掉了apache。    
不过随后发现了一个问题，随意进入某一有分页的网页，第一页是正常的（因为静态化过了）；点“下一页”，出来的页面两边正常，中间部分的标题、关键字等也正常，唯独每个标题下的正文无法正常显示。    
因为有做过系统调整，所以第一反应就是新上的nginx配置有问题。按照经验，可能是nginx.conf中指定的chaset与borwser不一致？但选定utf8后现象依旧，何苦同一页面内的其他字符又是正确显示的~~~    
然后通过内网IP+端口的方式，直接向resin请求抓取到的乱码页面url。结果，nginx+resin的机器显示乱码，apache+resin的机器显示中文——由此确认问题不是nginx，而是resin的！    
diff两台机器的resin.conf，除了开启的端口外，没有任何不同的地方。    
检查两台机器的环境变量，发现nginx这台的LANG是zh_CDN:gbk（静态化程序有需求），而apache这台是utf8。试着也修改成utf8然后重启resin，访问结果依然不对。    
这下基本没招了……完全一样的环境和配置，取的同一台nfs的数据，为啥就能显示不同呢？难道是编译参数的问题？    
去sharepoint上下载公司文档，查看原先的resin都使用了那些configure选项。结果发现为了配合apache，使用了--with-apache等。莫非就是因为这个原因导致resin脱离apache运行出现问题了？    
下载和现行resin版本一致的源码报，不再with-apache编译完成，cp一份conf过来，改用另一个端口启动，然后通过这个端口访问那个url，结果显示正常了！    
替换下原先的resin，把nginx的upstream指向新resin，故障解决。    
看来以后再替换apache+resin成nginx+resin的时候，resin也要重新编译一个了……    
    
