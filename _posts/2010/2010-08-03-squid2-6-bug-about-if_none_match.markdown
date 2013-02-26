---
layout: post
title: squid2.6的bug（if-none-match）
date: 2010-08-03
category: CDN
tags:
  - squid
---

话接上篇。
在发现经过squid的刷新请求头不带If-None-Match后，向squid-user发邮件询问。Amos回复如下：

On Mon, 02 Aug 2010 07:56:09 +0800, Gemmy <a href="mailto:chenryn@163.com"><span style="text-decoration:underline;"><span style="color:#0000ff;"><chenryn@163.com></span></span></a> wrote:
<blockquote style="color:#000000;">
 Hi~
> I have a nginx webserver adding the static-etags module and a
> squid2.6.23 before the nginx. When I access to the nginx directly, I can
> see the ETag in response header and If-None-Match in the request header
> after refresh. But when I access to the squid, ETag header still
> exist,If-None-Match header disappeared!
> The squid.conf have most basic configuration items, nothing about cache.
> Why does this happen?
</blockquote>
Squid-2 has problems with If-None-Match.
<a href="http://bugs.squid-cache.org/show_bug.cgi?id=2112"><span style="text-decoration:underline;"><span style="color:#0000ff;">http://bugs.squid-cache.org/show_bug.cgi?id=2112</span></span></a>

Please upgrade to Squid-2.7. It will behave a lot better regarding ETags
in general and <a href="http://bugs.squid-cache.org/show_bug.cgi?id=2112"><span style="text-decoration:underline;"><span style="color:#0000ff;">http://bugs.squid-cache.org/show_bug.cgi?id=2112</span></span></a> has some
patches on 2.7 that you may want to try.

Amos

赶紧看看bug2112报告《Squid does not send If-None-Match tag for cache revalidation》，原来是http.c里，虽然
httpBuildRequestHeader定义了if-none-match，但却忘了定义接下来向源站发送的request-etags！
重新下载squid2.7.9，编译完成后开始测试。访问动作和相应的日志记录如下：
第一次访问：
1280803634.566     65 59.108.42.242 TCP_MISS/200 19127 GET <a href="http://club.china.com/data/thread/1011/2716/16/81/5_1.html">http://club.china.com/data/thread/1011/2716/16/81/5_1.html</a> - ROUNDROBIN_PARENT/127.0.0.1 text/html "<a href="http://club.china.com/">http://club.china.com/</a>" "Mozilla/5.0 (Windows; Windows NT 5.1; rv:2.0b2) Gecko/20100720 Firefox/4.0b2"
F5刷新有新内容：
1280803714.220    488 59.108.42.242 TCP_REFRESH_MISS/200 19127 GET <a href="http://club.china.com/data/thread/1011/2716/16/81/5_1.html">http://club.china.com/data/thread/1011/2716/16/81/5_1.html</a> - ROUNDROBIN_PARENT/127.0.0.1 text/html "<a href="http://club.china.com/">http://club.china.com/</a>" "Mozilla/5.0 (Windows; Windows NT 5.1; rv:2.0b2) Gecko/20100720 Firefox/4.0b2"
F5刷新没新内容：
1280805207.149      3 59.108.42.242 TCP_REFRESH_HIT/304 309 GET <a href="http://club.china.com/data/threads/1011/1.html">http://club.china.com/data/threads/1011/1.html</a> - ROUNDROBIN_PARENT/127.0.0.1 text/html "-" "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)"
回复后返回新内容：
1280803803.696     20 59.108.42.242 TCP_REFRESH_HIT/200 19126 GET <a href="http://club.china.com/data/thread/1011/2716/16/81/5_1.html">http://club.china.com/data/thread/1011/2716/16/81/5_1.html</a> - ROUNDROBIN_PARENT/127.0.0.1 text/html "<a href="http://r.club.china.com/jsp/pub/replyAutoJump.jsp?url=http://club.china.com/data/thread/1011/2716/16/81/5_1.html&amp;forumid=1011&amp;message=&amp;picmessage">http://r.club.china.com/jsp/pub/replyAutoJump.jsp?url=http%3A%2F%2Fclub.china.com%2Fdata%2Fthread%2F1011%2F2716%2F16%2F81%2F5_1.html&amp;forumid=1011&amp;message=&amp;picmessage</a>=" "Mozilla/5.0 (Windows; Windows NT 5.1; rv:2.0b2) Gecko/20100720 Firefox/4.0b2"
Ctrl+F5刷新：
1280803821.731     12 59.108.42.242 TCP_CLIENT_REFRESH_MISS/200 19127 GET <a href="http://club.china.com/data/thread/1011/2716/16/81/5_1.html">http://club.china.com/data/thread/1011/2716/16/81/5_1.html</a> - ROUNDROBIN_PARENT/127.0.0.1 text/html "<a href="http://r.club.china.com/jsp/pub/replyAutoJump.jsp?url=http://club.china.com/data/thread/1011/2716/16/81/5_1.html&amp;forumid=1011&amp;message=&amp;picmessage">http://r.club.china.com/jsp/pub/replyAutoJump.jsp?url=http%3A%2F%2Fclub.china.com%2Fdata%2Fthread%2F1011%2F2716%2F16%2F81%2F5_1.html&amp;forumid=1011&amp;message=&amp;picmessage</a>=" "Mozilla/5.0 (Windows; Windows NT 5.1; rv:2.0b2) Gecko/20100720 Firefox/4.0b2"




