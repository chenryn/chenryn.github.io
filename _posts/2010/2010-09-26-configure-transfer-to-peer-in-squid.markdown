---
layout: post
title: squid回源选择配置小结
date: 2010-09-26
category: squid
---
一共关系到cache_peer/always_direct/never_direct/hierarchy_stoplist/prefer_direct等配置项。

squid的<a href="http://www.deckle.co.za/squid-users-guide/Cache_Hierarchies#The_always_direct_and_never_direct_tags" target="_blank">使用指南</a>上，关于always_direct和never_direct这么写到：

Squid checks all <em>always_direct</em> tags before it checks any <em>never_direct</em> tags. If a matching <em>always_direct</em> tag is found, Squid will not check the <em>never_direct</em> tags, but decides which cache to talk to immediately....
If the line used the <em>deny</em> keyword instead of <em>allow</em>, Squid would have simply skipped on to checking the <em>never_direct</em> lines

squid的<a href="http://http://www.squid-cache.org/Doc/config/hierarchy_stoplist/" target="_blank">配置说明</a>上，关于hierarchy_stoplist这么写到：

use this to not query neighbor caches for certain objects....never_direct overrides this option

squid的<a href="http://www.squid-cache.org/mail-archive/squid-users/201009/0330.html" target="_blank">邮件列表</a>上，Amos这么解释：

always_direct *prevents* peers being used. It does not force them. " hierarchy_stoplist ? " is the directive preventing the peer being used.

看起来挺让人晕头转向的。
其实就是说：

always_direct allow的优先级高于never_direct，但deny（包括allow !）时则不。    
hierarchy_stoplist强制请求通过域名解析回源，但never_direct又优先于它。    
prefer_direct用于所有cache_peer都down了时，never_direct会报错，而prefer会转入dns解析。     

