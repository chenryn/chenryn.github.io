---
layout: post
title: memcached部署
date: 2010-02-25
category: web
---
```bash
wget http://www.monkey.org/~provos/libevent-1.4.13-stable.tar.gz
wget http://memcached.googlecode.com/files/memcached-1.4.4.tar.gz
wget http://pecl.php.net/get/memcache-2.2.5.tgz
tar zxvf libevent-1.4.13-stable.tar.gz
tar zxvf memcached-1.4.4.tar.gz

cd libevent-1.4.13-stable
./configure --prefix=/usr
make
make install
ln -s /usr/lib/libevent-1.4.so.2 /usr/lib64/libevent-1.4.so.2

cd memcached-1.4.4
./configure --prefix=/home/memcached --enable-64bit
make
make install
/home/memcached/bin/memcached -d -m 1024 -p 11211 -u root
```

参数说明：
    -d 启动为守护进程
    -m <num> 分配给Memcached使用的内存数量，单位是MB，默认为64MB
    -u <username> 运行Memcached的用户，仅当作为root运行时
    -l <ip_addr> 监听的服务器IP地址，默认为环境变量INDRR_ANY的值
    -p <num> 设置Memcached监听的端口，最好是1024以上的端口
    -c <num> 设置最大并发连接数，默认为1024
    -P <file> 设置保存Memcached的pid文件，与-d选择同时使用

```bash
cd memcache-2.2.5
/home/php/bin/phpize
./configure --prefix=/home/phpmemcache --with-php-config=/home/php/bin/php-config
make
make install
sed –i ‘s:./:/home/php/lib/php/extensions/no-debug-zts-20060613/:g’ /home/php/lib/php.ini
sed –i ‘/zip.dll/aextension=memcache.so’ /home/php/lib/php.ini

cat >> /cache/data/test.php <<EOF
<?php
$memcache = new Memcache;
/*$memcache->connect('localhost', 11211) or die ("Could not connect");
/*addServer方式更能体现分布式的优势，也完成故障转移，就是转移的时候HIT要重新开始*/
$memcache->addServer('127.0.0.1', 11211);
$memcache->addServer('192.168.0.2', 11212);
$version = $memcache->getVersion();
echo "Server's version: ".$version."<br/>n";
$tmp_object = new stdClass;
$tmp_object->str_attr = 'test';
$tmp_object->int_attr = 123;
$memcache->set('key', $tmp_object, false, 10) or die ("Failed to save data at the server");
echo "Store data in the cache (data will expire in 10 seconds)<br/>n";
$get_result = $memcache->get('key');
echo "Data from the cache:<br/>n";
var_dump($get_result);
?>
EOF
```

```bash
curl <a href="http://localhost/test.php">http://localhost/test.ph</a>
Server's version: 1.4.4<br/>
Store data in the cache (data will expire in 10 seconds)<br/>
Data from the cache:<br/>
object(stdClass)#3 (2) {
["str_attr"]=>
string(4) "test"
["int_attr"]=>
int(123)
}

# telnet localhost 11211
```
    Trying 127.0.0.1...
    Connected to localhost.localdomain (127.0.0.1).
    Escape character is '^]'.
    stats
    STAT pid 3015
    STAT uptime 3185                                 memcached运行的秒数
    STAT time 1267090234
    STAT version 1.4.4
    STAT pointer_size 64
    STAT rusage_user 0.000000
    STAT rusage_system 0.000000
    STAT curr_connections 10
    STAT total_connections 18
    STAT connection_structures 11
    STAT cmd_get 3                                   查询缓存的次数
    STAT cmd_set 5                                   设置key=>value的次数
    STAT cmd_flush 0
    STAT get_hits 3                                    缓存命中的次数
    STAT get_misses 0
    STAT delete_misses 0
    STAT delete_hits 0
    STAT incr_misses 0
    STAT incr_hits 0
    STAT decr_misses 0
    STAT decr_hits 0
    STAT cas_misses 0
    STAT cas_hits 0
    STAT cas_badval 0
    STAT auth_cmds 0
    STAT auth_errors 0
    STAT bytes_read 2697
    STAT bytes_written 1150
    STAT limit_maxbytes 1073741824
    STAT accepting_conns 1
    STAT listen_disabled_num 0
    STAT threads 4
    STAT conn_yields 0
    STAT bytes 1255
    STAT curr_items 2
    STAT total_items 5
    STAT evictions 0
    END

完成~~~以上仅为试验，如果只是一个小web单机环境的话，只需要php+eaccelerator（或者apc/xcache等）就足够了。用php+memcached+mysql-proxy+mysql是大型网站架构的事情~~


