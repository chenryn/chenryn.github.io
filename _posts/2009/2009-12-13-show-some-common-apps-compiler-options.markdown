---
layout: post
theme:
  name: twitter
title: 查看一些常见应用的编译选项
date: 2009-12-13
category: linux
---

* nginx：
```bash
[rao@localhost ~]$ /home/nginx/sbin/nginx -V|grep conf
nginx version: 0.7.54
built by gcc 4.1.2 20080704 (Red Hat 4.1.2-44)
configure arguments: --prefix=/home/nginx --with-pcre
--with-http_stub_status_module --without-http_memcached_module
--without-http_fastcgi_module
apache:
[rao@localhost ~]$ cat /home/apache2/build/config.nice
#! /bin/sh
#
# Created by configure
CFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"; export
CFLAGS
"./configure"
"--prefix=/home/apache2"
"--enable-static-support"
"--enable-rewrite"
"--with-mpm=worker"
"--enable-logio"
"--enable-so"
"--enable-mime-magic"
"--disable-cgid"
"--disable-cgi"
"--disable-userdir"
"--disable-dir"
"--disable-include"
"--disable-filter"
"--disable-env"
"--disable-setenvif"
"--disable-status"
"--disable-autoindex"
"--disable-asis"
"--disable-alias"
"--disable-actions"
"--disable-authn-file"
"--disable-authn-default"
"--disable-authz-default"
"--disable-authz-groupfile"
"--disable-authz-user"
"--disable-auth-basic"
"CFLAGS=-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
"$@"
```

* php:

```bash
[rao@localhost ~]$ php -i|grep configure
Configure Command =>  './configure'
'--build=x86_64-redhat-linux-gnu' '--host=x86_64-redhat-linux-gnu'
'--target=x86_64-redhat-linux-gnu' '--program-prefix='
'--prefix=/usr' '--exec-prefix=/usr' '--bindir=/usr/bin'
'--sbindir=/usr/sbin' '--sysconfdir=/etc' '--datadir=/usr/share'
'--includedir=/usr/include' '--libdir=/usr/lib64'
'--libexecdir=/usr/libexec' '--localstatedir=/var'
'--sharedstatedir=/usr/com' '--mandir=/usr/share/man'
'--infodir=/usr/share/info' '--cache-file=../config.cache'
'--with-libdir=lib64' '--with-config-file-path=/etc'
'--with-config-file-scan-dir=/etc/php.d' '--disable-debug'
'--with-pic' '--disable-rpath' '--without-pear' '--with-bz2'
'--with-curl' '--with-exec-dir=/usr/bin' '--with-freetype-dir=/usr'
'--with-png-dir=/usr' '--enable-gd-native-ttf' '--without-gdbm'
'--with-gettext' '--with-gmp' '--with-iconv' '--with-jpeg-dir=/usr'
'--with-openssl' '--with-png' '--with-pspell'
'--with-expat-dir=/usr' '--with-pcre-regex=/usr' '--with-zlib'
'--with-layout=GNU' '--enable-exif' '--enable-ftp'
'--enable-magic-quotes' '--enable-sockets' '--enable-sysvsem'
'--enable-sysvshm' '--enable-sysvmsg' '--enable-track-vars'
'--enable-trans-sid' '--enable-yp' '--enable-wddx'
'--with-kerberos' '--enable-ucd-snmp-hack'
'--with-unixODBC=shared,/usr' '--enable-memory-limit'
'--enable-shmop' '--enable-calendar' '--enable-dbx' '--enable-dio'
'--with-mime-magic=/usr/share/file/magic.mime' '--without-sqlite'
'--with-libxml-dir=/usr' '--with-xml' '--with-system-tzdata'
'--enable-force-cgi-redirect' '--enable-pcntl' '--with-imap=shared'
'--with-imap-ssl' '--enable-mbstring=shared'
'--enable-mbstr-enc-trans' '--enable-mbregex'
'--with-ncurses=shared' '--with-gd=shared' '--enable-bcmath=shared'
'--enable-dba=shared' '--with-db4=/usr' '--with-xmlrpc=shared'
'--with-ldap=shared' '--with-ldap-sasl' '--with-mysql=shared,/usr'
'--with-mysqli=shared,/usr/bin/mysql_config' '--enable-dom=shared'
'--with-dom-xslt=/usr' '--with-dom-exslt=/usr'
'--with-pgsql=shared' '--with-snmp=shared,/usr'
'--enable-soap=shared' '--with-xsl=shared,/usr'
'--enable-xmlreader=shared' '--enable-xmlwriter=shared'
'--enable-fastcgi' '--enable-pdo=shared'
'--with-pdo-odbc=shared,unixODBC,/usr'
'--with-pdo-mysql=shared,/usr' '--with-pdo-pgsql=shared,/usr'
'--with-pdo-sqlite=shared,/usr' '--enable-dbase=shared'
```

* mysql:
据网上都说是cat /usr/bin/mysqlbug|grep conf，但我这的结果是压根没用……


