---
layout: post
title: 忽略大小写（刚在nginx的maillist看到的）
date: 2010-03-13
category: nginx
---

想找找解决不同client请求中文url产生多份cache的办法，结果在nginx的maillist里看到也有人问《<a href="http://forum.nginx.org/read.php?2,48527" target="_blank">rewrite to lowercase?</a>》下面有人回答了这个问题，做法和我一样~~呵呵。随后他也附上了这种做法的思路和问题。

    The first option (with the if and http://$host) sends an HTTP redirect
    to the lowercase URL if the requested URL is not completely in
    lowercase. I like this approach better as it kind of normalizes all URL
    to a canonical form.. The second option (without if nor http://) just accepts
    any URL and internally rewrites them to lowercase: if you rename all
    your directories and files to lowercase, this will imitate Windows'
    case-insensitive behaviour.

第一个办法：采用if语句判断url是否有大写字母在内，有则重定向，作者本人比较喜欢这种方式，因为这样返回的url是符合标准规范的；第二个方法，采用internal方式重定向所有uri，就像windows主机的做法一样。

    Kudos to the following post were I
    draw the "inspiration" :D from to get this done. The embedded perl doc
    and examples are indeed scarce. :-(

最后作者也感慨了一句：nginx的内置perl模块的文档和配置案例实在是太少了……
    Anyway I see two problems in this approach:
然后说说这种办法的两个问题：

    - you need the
    embedded perl module which according to the docs is experimental and can
    lead to memory leaks.

这个方法是基于内嵌perl模块的，而根据官方文档的说明，有可能导致内存泄漏！

    - the actual redirection is done with the
    rewrite, which you can put on the location you need. But the URL
    lowercase calculation, being on the "http" section of the config, is
    done for each and every request arriving to your server. Say you have a
    virtual server with 10 domains and you only need this on one particular
    location of one of them. The lowercase URL is going to be calculated for
    every request of every domain.

rewrite语句是在location段的，而perl_set语句是在http段的。也就是说，每一个请求过来，都被转化大小写了。如果你的服务器上配了十个虚拟主机，却只想忽略一个的大小写，这个换算依然要在所有域名中都执行的……

    I guess that by defining a perl
    function the URL calculation could be restricted to a particular
    location, have to look into it further. Another option is writing a C
    module.

我想在location段里另建perl函数换算url（即perl_module/perl_require），不过这是以后的事了；或者干脆用C语言写个模块。

在继续往下翻的时候，看到两条感兴趣的话，一是nginx开发者正在完成updating_file_lock的功能，解决第一次MISS的时候同时向origin并发请求的问题；二是正在完善cache_path和temp_pache必须在同一个文件系统的link()的功能，这样就可以在每个server下指定特定的cache_path了。


