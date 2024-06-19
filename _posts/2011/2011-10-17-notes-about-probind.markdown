---
layout: post
theme:
  name: twitter
title: ProBIND体验笔记
date: 2011-10-17
category: DNS
tags:
  - php
---

闲的无聊，继续研究DNS周边产品，这次盯上了Probind。这是搜索结果中比较常见的bind的web管理工具。其实我是比较希望有个中文的东东方便我偷懒，可惜看sina之前的xbayDNS一直停留在了只支持FreeBSD/MAC的阶段没有更新，汗，不支持linux的项目偶见过的还真不多……
probind最近一次更新也是2003/05/24的事情了。所以也没期待它能多么适应现在的bind体系，不过作为代码看看还是可以的。
创建mysql用户和库，然后把程序解压到webroot目录，然后执行mysql -u named -p named < etc/mktables.sql，这就是install的步骤。但是这个时候访问首页是有一堆报错的，提示你dns服务器的默认配置（外部检测用dns，管理员邮箱等等）没配置。这个需要通过./tools/settings.php去添加——但是首页上没有链接点击，得自己手敲url，汗……
然后，probind更新的时候，估计php还是以version4为主，所以里头用的还是$HTTP_GET_VARS和$HTTP_POST_VARS等全局变量。奇怪的是我把php.ini里的register_global改成On后重启httpd了，页面依然没变，不得已在./inc/lib.inc文件的开头加上了两句
```php$HTTP_GET_VARS = &$_GET;
$HTTP_POST_VARS = &$_POST;```才好。
OK，现在正式看到probind的页面了。demo地址：<a href="http://chenlinux.com/probind/">点这里</a>
主要就是一个zone的管理，有add、delete、browse三个页面，前两个就是标准的表单，倒是browse里有个test，蛮好玩的，调用bin/testns脚本，使用perl的Net::DNS模块测试zone内的正/反向解析是否正常。
然后就是record的管理，在browse zones里点进zone就可以编辑record了，主要就是主机名、解析ip。
最后是server的管理，这里管理的是真实的DNS的ip和type(master|slave)——probind在易用和性能之间取了一个平衡，他不是像mysqlbind或者mysql-dlz那样直接从db里取数据做响应，而是每次更新(这里区分开了步骤，update的时候只是更新了db，然后再去bulk update的时候才是真正update dns配置)的时候，从数据库生成文件(bin/mkzonefile)，再同步到DNS服务器上(sbin/push.local|remote)并执行rndc reconfig命令。
<hr />
每次添加一个server的时候，都会在probind/HOSTS/目录下生成一个同名目录，里面存有从template复制出来的named.tmpl模板，reconfig.sh脚本，rndc.conf和root.hint。
由上可见：
第一，其实probind的管理方式，很像一个简单的集中式配置管理系统；
第二，probind虽然号称支持bind9，但是缺失了现在来看最关键的acl+view体系。不过想到第一点，其实加一个view配置也不是很复杂。大概列一下：
新建views表，包括id、area、iplist和zonefile字段；
修改records表，把关联zones.id的zone改成view关联views.id；
修改inc/lib.inc文件，把add_domain()里的$zonefile命名从$domain.dns改成$domain+$views.id的格式。
修改brzones.php页面，改成先browse views，然后在view里面再选zones；
和template的小小变动。这个可能就多了……
