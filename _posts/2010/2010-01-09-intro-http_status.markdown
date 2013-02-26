---
layout: post
title: squid3新acl类型http_status试用（源站故障转向研究）
date: 2010-01-09
category: squid
---

今天试着自己编译安装了squid3.1，然后开始移植2.6的配置文件。在squid.conf.document（2.6里的squid.conf.default）里看了很久，发现不少新东西。跟转向有关的，便发现一个：

acl aclname http_status 200 301 500- 400-403
...
# status code in reply

这个acl配合http_access和deny_info，也是个转向的办法。（相反的，大家举例时一般用来deny的正是302跳转）

acl err http_status 500-
http_access deny err
deny_info http://err.tiaozhuan.com err

不过问题依旧：这个依然没法把不同的域名分开——deny_info只针对自己上头那个http_access deny的aclname，可要是写上同样aclname的astdomain或者url_regex，整个访问就都废了……
然后想到url_rewrite_access，如果用acl http_status配合url_rewrite_access，能不能做到避免所有请求回源确认呢？
按照之前记录的squid处理流程，squid应该是在和client建立连接后的第二步就检查acl。但3.1中添加的这个http_status，总不可能在命中的第四步或者回源的第六步之前，就能完成访问控制呀？
看来squid的内部机制，已经有了较大变化。
明天做个实验，看看实际到底如何吧~
<hr />
经过试验，第一个想法不可行。因为deny_info的status是TCP_DENY/302，这和acl是冲突的，导致无法工作。从此也能看出，http_status的acl确实是在比较晚的流程中才起作用的。分别使用http_status和url_regex做deny的日志如下：
    1263112949.310 27099 12.34.56.78 TCP_MISS/502 1878 GET http://a.b.com/duanzu/ - DIRECT/1.2.3.4 text/html "http://a.b.com/" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; QQPinyinSetup 620; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"
    1263113026.271 0 12.34.56.78 TCP_DENIED/302 331 GET http://a.b.com/duanzu/ - NONE/- text/html "http://a.b.com/" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; QQPinyinSetup 620; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"

acl err http_status 500-
url_rewrite_access deny !err

不起作用，所有的请求都不经过rewrite直接输出了……
郁闷，这个新acl的用法还得慢慢找资料~~
