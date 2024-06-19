---
layout: post
theme:
  name: twitter
title: 防盗链二进阶（squid外部ACL）
date: 2010-01-31
category: CDN
tags:
  - squid
---

服务器防盗链设置，从最简单的referer判断，到进阶的key+time生成md5值，应该说是比较可靠了，而还有一种防盗链方式，基于IP/COOKIE的，这个我没找到太多有用信息，似乎IIS有个相关插件？
只看到一篇squid的相关文章，简单的举了个防盗链的例子，未必有效（因为把cookie做明文处理，相比md5加密实在是防君子不防小人）。倒是从中学习一下external_acl_type用法，对squid进阶一番罢~~
首先按惯例，上权威：《squid中文权威指南》6.1.3章节和12.5章节。
用法如下：
external_acl_type name [options] FORMAT.. /path/to/helper
[helper arguments..]
options包括：ttl、negtive_ttl、children、concurrency、cache和grace；
FORMAT包括：%LOGIN,%EXT_USER,%IDENT,%SRC,%SRCPORT,%DST,%PROTO,%PORT,%METHOD,%MYADDR,%MYPORT,%PATH,%USER_CERT,%USER_CERTCHAIN,%USER_CERT_xx,%USER_CA_xx,%{Header},%{Hdr:member},%{Hdr:;member},%ACL,%DATA。
外部程序输出结果必须是OK或者ERR，不过可以再带上一些keyword，比如user/passwd，ERR的messages，access.log里记录的%ea等等。
cookie防盗链举例squid/libexec/check_cookie.pl如下：
```perl
#!/usr/bin/perl -w
# 这个脚本仅仅是验证了Cache这个cookie的存在，没有严格的校验其值。
# disable output buffering
$|=1;
while () {
    chop;
    $cookie=$_;
    if( $cookie =~ /$COOKIE/i) {
        print "OK\n";
    } else {
        print "ERR\n";
    }
}
```
squid.conf配置如下：
```squid
external_acl_type download children=15 %{Cookie} squid/libexec/check_cookie.pl
acl dl external download
acl filetype url_regex -i .wmv .wma .asf .asx .avi .mp3 .smi .rm .ram .rmvb .swf .mpg .mpeg .mov .zip .mid
http_access deny filetype !dl
```
回过头来，想到之前的squid_session一文中，也是用的这个外部ACL~~

