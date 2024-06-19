---
layout: post
theme:
  name: twitter
title: HTTP的auth请求模拟
date: 2011-01-11
category: web
---

开发同事需要在程序中调用一个“安全级别比较高”的url，起初没觉得有啥问题，我们wget或者curl的时候，按照标准url的格式（即'请求方法://用户名:密码@域名/文件路径'）写就完全OK了。不过很快同事转来了报错：

<span style="color:#000000;font-family:Verdana;font-size:x-small;"><span style="font-family:Verdana;font-size:x-small;"><span style="font-family:Verdana;font-size:x-small;">java.io.IOException: Server returned HTTP response code: 401 for URL: <a href="http://gundong:gdxw6354@editornew.china.com/interface/addcategory.php?parentid=2&amp;id=2&amp;name=gbox_%D0%C7%BC%CA%D5%F9%B0%D4&amp;groupname=game&amp;code=satrcraft&amp;m=09286f9d135d5debe7052bea42a27eef">http://test:test1234@test.domain.com/interface/addcategory.php?parentid=2&amp;id=2&amp;name=gbox_%D0%C7%BC%CA%D5%F9%B0%D4&amp;groupname=game&amp;code=satrcraft&amp;m=09286f9d135d5debe7052bea42a27eef</a></span></span></span>
原来用的是IO的方式，我用telnet模拟一下，结果还真是这样：
```bash[root@cms ~]# telnet test.domain.com 80
Trying 123.124.125.126...
Connected to test.domain.com (123.124.125.126).
Escape character is '^]'.
GET http://test:test1234@test.domain.com/interface/addcategory.php?parentid=2&amp;id=2&amp;name=gbox_%D0%C7%BC%CA%D5%F9%B0%D4&amp;groupname=game&amp;code=satrcraft&amp;m=09286f9d135d5debe7052bea42a27eef HTTP/1.0

HTTP/1.1 401 Authorization Required
Date: Tue, 11 Jan 2011 03:39:37 GMT
Server: Apache/1.3.37 (Unix) PHP/4.4.9
WWW-Authenticate: Basic realm="CMS-Testdotcom"
Connection: close
Content-Type: text/html; charset=iso-8859-1```
查了一下HTTP协议，原来auth是走的另外一个header完成Authorization，其格式是Authorization: Basic 'encoded_base64(user:passwd)'。服务器会自动的用decoded_base64()解析字符串得到真正的用户名和密码。原来wget和curl这些工具不单单是发个请求这么简单啊~~

重新试验，先计算test:test1234的base64值：
```bash[root@cms ~]# echo test:test1234|openssl base64
dGVzdDp0ZXN0MTIzNAo=
[root@cms ~]# telnet test.domain.com 80
Trying 123.124.125.126...
Connected to test.domain.com (123.124.125.126).
Escape character is '^]'.
GET http://test.domain.com/interface/addcategory.php?parentid=2&amp;id=2&amp;name=gbox_%D0%C7%BC%CA%D5%F9%B0%D4&amp;groupname=game&amp;code=satrcraft&amp;m=09286f9d135d5debe7052bea42a27eef HTTP/1.0
Authorization: Basic dGVzdDp0ZXN0MTIzNAo=

HTTP/1.1 200 OK
Date: Tue, 11 Jan 2011 05:21:32 GMT
Server: Apache/1.3.37 (Unix) PHP/4.4.9
X-Powered-By: PHP/4.4.9
Connection: close
Content-Type: text/html
2 || 2|| gbox_星际争霸 || satrcraft || game <br/>09286f9d135d5debe7052bea42a27eef<br/>2Connection closed by foreign host.```
果然就可以了~~
