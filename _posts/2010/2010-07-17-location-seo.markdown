---
layout: post
title: 域名切换导致的 SEO 问题
date: 2010-07-17
category: web
---

网站某频道准备启用新域名，切换过程中，为了保证网民访问效果，对老域名下的所有请求设置了重定向到新域名下相同url。测试访问正常后上线使用。

过几天，发现该频道在各搜索引擎的收录数和关键词排名中都消失了！

## SE0 收录的问题

原来对于搜索引擎来讲，301永久重定向与302临时重定向属于不同情况。它们认可301永久重定向规则，并依此规则转移原请求的数据……

照此修改nginx配置

```nginx
server {
    server_name old.domain.com;
    #rewrite ^/(.*)$ http://new.domain.com/$1 last;
    rewrite ^/(.*)$ http://new.domain.com/$1 permanent;
}
server {
    #server_name old.domain.com toold.domain.com;
    server_name new.domain.com toold.domain.com;
    root /www/old.domain.com;
    index index.html;
}
```

配置生效后，收录逐渐恢复。

目前查询的结果，新老域名的google收录比为28600:46100，百度收录比为1200:97400。

据网友经验，百度对301重定向大概也需要3个月左右的时间才能完全反应过来……汗死

## google PR的问题

收录解决后，PR的问题又报出来了。目前查询结果，old.domain.com的PR为6，new.domain.com的PR还是0，而且toolod.domain.com的PR也是6，并提示可能是劫持了old.domain.com的PR！

只好再去看PR的资料……PR是google发明的对页面重要性等级的分析算法。从0到10非等比升高。主要是通过相互之间的链接来衡量得出的，外部链接的PR越高，网站得到的PR评分也越高（粗略的说）。对于google来说，google、yahoo等搜索引擎的收录，显然是PR衡量中极为重要的（google自定为10，yahoo、baidu等搜索是9，sina等门户是8…）显然，对于网站域名迁移切换来说，搜索引擎的收录数迁移是基础。    

不过收录转移完了，PR也变不了——因为PR计算太复杂了，哪怕以google的实力也不可能做到实时更新，而是几乎2.5-3个月才更新一次！    

同时，据google的Webspam团队老大Matt Cutts说：即使在域名迁移中使用301重定向，在PR统计时，也会有一定的损失！    

总之，想看到new.domain.com的PR恢复成6，耐心等待吧……    

然后研究toold的劫持PR报告是怎么来的……    

一般大家的说法，劫持PR都是采用重定向或者别名的方式（上面提到了，这个方式也不会获得完全一样的PR）。显然我这里的情况不是。    

也有人说，劫持PR直接A到IP更方便。也有人怀疑自己租机建站得到的是其他站的PR，难道相同IP的域名PR都会一样？查询一下和new.domian.com在同一台nginx上的另一个域名，PR是5。猜测不对。    

或许，因为toold读取的网页文件和old是一致的，所以获得的外链也一致。但外面的反向链接，肯定指的都是old而不是toold，导致toold的反链数过少，所以被怀疑为PR劫持了。    

不过，据编辑说，toold这个域名从来就没有上线发布使用过，搜索引擎从哪里抓到的页面呢？    

nginx 的同一 server{} 段内的多个 `server_name` 配置，默认只会把第一个域名设定为 `$server_name`。    

dns 上也没有配反向解析。    

实在想不到还有哪里能泄露出这个toold了……    
    
