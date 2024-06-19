---
layout: post
theme:
  name: twitter
title: 要命的刷新
date: 2010-04-22
category: CDN
---

今天一天都在跟刷新做斗争。
先是squid的目录刷新，用/home/squid/bin/squidclient -p 80 mgr:objects|awk '/harbin/{system("/home/squid/bin/squidclient -p 80 -m purge "$2}'刷新一遍；客户反馈看到的依然是旧页面；我想想似乎看到url里有带()的，awk的system函数这时候会出错；于是改成用for i in `/home/squid/bin/squidclient -p 80 mgr:objects|awk '/harbin/{print $2}'`;do /home/squid/bin/squidclient -p 80 -m purge "$i";done再刷新一遍；然后自己绑定节点访问，居然也还看到是旧页面！

通过httpwatch抓取，其中的http://www.harbin-beer.cn/flash/age.swf的Age高达23325，显然没有被purge到，单独提交/home/squid/bin/squidclient -p 80 -m purge http://www.harbin-beer.cn/flash/age.swf，再访问，Ok了！！
毫无疑问http://www.harbin-beer.cn/flash/age.swf这个url绝对是能被/harbin/模式匹配的，但为什么之前刷新不到？而且不单单是某一台服务器如此。。。

然后是nginx的url刷新，某小图片加速客户原先是增量缓存，于是nginx中只是很简单的配置了一下文件类型和缓存时间。不料今天客户突然传过来一个24M大小的url列表，将近30万条url要求全网刷新！而这批nginx连后台刷新接口都没有……哭
临时更换nginx版本为--add-ngx_cache_purge的。在设置proxy_cache_purge时却又碰到了难题。因为之前的cache配置里压根没配置proxy_cache_key！！有心格盘，但一算，300000*5k=1.5G，而cache已存文件是100G，格盘动作太大了……
进到nginx的cache目录下，strings其中的文件，看到如下信息：
```bash
[root@ct5 ~]# strings /cache/0/00/c7de957045a9987b18f94d3cc1f99000 |head
KEY: http://images6.anjukestatic.com/property/20090904/22/65/91/69/22659169/600x600.jpg
HTTP/1.0 200 OK
Server: nginx
Date: Thu, 11 Mar 2010 15:48:20 GMT
Content-Type: image/jpeg
ajk: server=img01-001
Expires: Thu, 31 Dec 2037 23:55:55 GMT
Cache-Control: max-age=315360000
X-Cache: HIT from CDN01-001
Age: 1465699
```
对照其他带purge的nginx_cache格式，可以发现nginx默认的proxy_cache_key应该是$scheme://$host$uri$is_args$args，那么proxy_cache_purge就设成$scheme://$host$1$is_args$args，重读配置，然后curl -x 127.0.0.1:80 http://images6.anjukestatic.com/purge/property/20090904/22/65/91/69/22659169/600x600.jpg，看到
```html
<html>
<head><title>Successful purge</title></head>
<body bgcolor="white">
<center><h1>Successful purge</h1>
<br>Key : http://images6.anjukestatic.com/property/20090904/22/65/91/69/22659169/600x600.jpg
<br>Path: /cache/0/00/c7de957045a9987b18f94d3cc1f99000
</center>
<hr><center>nginx/0.7.65</center>
</body>
</html>
```
（写到这里，想到google首页源代码省略了</body></html>，据说是因为就少这几个字符，在全球就能节省几个G的带宽。相比来说这个purgemodule可真浪费的）
再ls /cache/0/00/c7de957045a9987b18f94d3cc1f99000，提示No such file or directory，成功了。接下来就是for循环刷新了……


