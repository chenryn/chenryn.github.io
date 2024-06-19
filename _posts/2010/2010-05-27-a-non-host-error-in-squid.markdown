---
layout: post
theme:
  name: twitter
title: 一个少见的squid报错
date: 2010-05-27
category: squid
---

今天有客户传过来一张报障截图，乍一看很正常的拒绝访问而已。可仔细一看，吓，地址栏里的url和errorpage返回的%U居然不一样！！
<img src="/images/uploads/e68aa5e99a9ce688aae59bbe.jpg" />
浏览器中写的是域名，squid却按配置拒绝的是对服务器ip发起的直接请求。
赶紧去日志服务器上汇总deny信息，终于找到了相关日志。都是一个ip发过来的，大概如下：
2010-05-25-14:04:13 0 60.209.232.219 TCP_MEM_HIT/200 15555 GET http://jobseeker.zhaopin.com/zhaopin/aboutus/law.html - NONE/- text/html "-" "-"
2010-05-25-14:05:19 2 60.209.232.219 TCP_DENIED/403 1464 GET http://113.6.255.97/zhaopin/aboutus/law.html - NONE/- text/html "-" "-"
2010-05-25-14:06:01 1 60.209.232.219 TCP_DENIED/403 1464 GET http://113.6.255.97/zhaopin/aboutus/law.html - NONE/- text/html "-" "-"
2010-05-25-14:10:00 1 60.209.232.219 TCP_DENIED/403 1464 GET http://113.6.255.97/zhaopin/aboutus/law.html - NONE/- text/html "-" "-"
2010-05-25-14:10:00 0 60.209.232.219 TCP_MEM_HIT/200 679 GET http://jobseeker.zhaopin.com/favicon.ico - NONE/- application/octet-stream "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-TW; rv:1.9.0.11) Gecko/2009060215 Firefox/3.0.11 (.NET CLR 3.5.30729)"
2010-05-25-14:12:39 2 60.209.232.219 TCP_DENIED/403 1464 GET http://113.6.255.97/zhaopin/aboutus/law.html - NONE/- text/html "-" "-"
2010-05-25-14:12:41 1 60.209.232.219 TCP_DENIED/403 1464 GET http://113.6.255.97/zhaopin/aboutus/law.html - NONE/- text/html "http://jobseeker.zhaopin.com/zhaopin/aboutus/law.html" "Mozilla/5.0 (Windows; U; Windows NT 5.1; zh-TW; rv:1.9.0.11) Gecko/2009060215 Firefox/3.0.11 (.NET CLR 3.5.30729)"
截图的那个时间点，日志中的user-agent居然是空！而且就在短短的一分钟前后，就连续出现正确和错误的反复访问。。。。。。在同事的提醒下，试着扫描了一下这个clientip，发现它还开着80端口：
```bash
Starting Nmap 4.11 ( <a href="http://www.insecure.org/nmap/"><u><font color="#0000ff">http://www.insecure.org/nmap/</font></u></a> ) at 2010-05-25 17:22 CST
Interesting ports on 60.209.232.219:
Not shown: 1679 filtered ports
PORT STATE SERVICE
80/tcp open http
Nmap finished: 1 IP address (1 host up) scanned in 37.623 seconds
```
目前只能猜测这个ip应该是一个代理网关服务器，在转发访问请求的时候，把header中的Host信息给弄没了~~
