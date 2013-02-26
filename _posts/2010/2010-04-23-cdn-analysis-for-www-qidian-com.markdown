---
layout: post
title: 起点小说网的cdn分析~（绝非正式报告）
date: 2010-04-23
category: CDN
---

每天习惯了在起点小说网看看小说轻松一下神经，今天一不小心，看见了squid错误页面。于是小小的查看了一下起点的cdn状况。
首先声明本身的接入情况：宽带通4M接入，ip138显示为北京网通adsl……
访问的是决战朝鲜的第三十三章。页面内容来看，域名主要有www.qidian.com、image.cmfu.com、ipagent.igalive.com、cj.qidian.com四个，前两个在网宿加速(lxdns)、第三个在蓝汛加速(ccgslb)、第四个在起点母公司盛大加速(sdo)，其余零散域名未加速。
lxdns返回的ip是天津网通（ping值7ms）；
ccgslb返回的ip是北京蓝汛（ping值8ms）；
sdo返回的是上海联通（本地ping不通，在沈阳网通测试机上居然ping通了，返回的是同一个ip，30ms，汗）……
整个页面一共81个对象:
加速的域名uedas.qidian.com和sdo的cj.qidian.com下的对象，time都在100ms以上；
网宿加速域名下的对象，主要是小图片和页面；
图片小到以B计算，返回time在16ms左右；页面包括aspx和html，html大小在15-20KB左右，返回time在50ms左右；
耗时最大的是主页面http://www.qidian.com/BookReader/1501306,27478560.aspx，耗时437ms，其中15ms建立链接，而422ms传输内容，content-length 69408，请求头带有no-cache的cache-control和gzip,deflate的压缩；返回头带有Age 1的HIT结果，但X-Cache有两层，分别是一层MISS一层HIT，via头信息是jsyz232:80 (Cdn Cache Server V2.0), tg146:80 (Cdn Cache Server V2.0)。预计应该是parent上设定强制缓存，而leaf上不缓存；
另一个耗时较大的是http://www.qidian.com/Javascript/ReadChapterNew.js?t=091216，耗时250ms，content-length 35423，其他情况和aspx差不多，不过返回了三个X-Cache，一个MISS两个HIT，在via头上很奇怪的看到三个服务器分别是jsyz232:80 (Cdn Cache Server V2.0), zb99:80 (Cdn Cache Server V2.0), tg134:8103 (Cdn Cache Server V2.0)，不知道这个开8103端口的是什么意思？？（网上查了一下，民生网银用的是这个端口，~~）
最后是蓝汛加速域名下的对象，都是广告；
js文件url是相同的，都是http://ipagent.igalive.com/show_ads.js，但先后请求了5次，返回时间依次为：4.28s、48.42s、3.14s、6.17s和875ms，波动相当大！观察这5次的Age，分别是778、827、782、834、835；对应返回时间，可以看出是同一台服务器返回的同一份缓存。再具体看time的细分，建立连接时间都很短，传输内容时间从500ms到1.5s不等。也就是说，主要波动在于服务器的响应时间上。
aspx?文件，url比较长，类似这种：http://ipagent.igalive.com/s.aspx?adid=100144&amp;host=http://ipagent.igalive.com&amp;dt=1272030174514&amp;lmt=1272028966&amp;output=101&amp;url=http://www.qidian.com/BookReader/1501306/27478560.aspx&amp;ref=http://me.qidian.com/BookCase/1/1&amp;flash=10&amp;u_h=660&amp;u_w=1126&amp;u_ah=627&amp;u_aw=1126&amp;u_cd=24&amp;u_tz=480&amp;u_his=1&amp;u_nplug=7&amp;u_nmime=16，都是MISS回源的。长度和上面的js差不多都在40KB左右。但是到最后甚至有一个文件连接超时了……</
<hr />综上：
网宿给起点的cache服务器，应该是针对超小文件做过优化的，所以在16KB以下的图片，返回TCP_MEM_HIT；超过这个大小的那两个文件，响应速度就下降的比较厉害。
蓝汛给起点的cache服务器，负载压力可能比较大，导致响应速度很慢且有极大波动；我猜测对于js文件，其服务器可能还采用了304回源；从回源的aspx来看，回源效果很差很差……
盛大给起点的cache服务器，不说啥了~~
最后附squid的错误信息ERR_READ_TIMEOUT图：
<img src="/images/uploads/err_read_timeout.jpg" alt="" />


