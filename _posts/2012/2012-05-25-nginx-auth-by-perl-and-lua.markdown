---
layout: post
theme:
  name: twitter
title: 用perl和lua在nginx中验证url
date: 2012-05-25
category: nginx
tags:
  - lua
  - perl
---
和三年前的博客一样，还是时间加密钥加路径的加密方式。不过这次改用nginx，这样不用重新缓存后面的squid文件了。
先用ngx_lua做：
```nginx
    set $expire "600";
    set $salt "mysalt";
    location ~* \.mp3$ {
#local m = ngx.re.match(ngx.var.uri,"^/([0-9]{4})/([0-9]{2})/([0-9]{2})/([0-9]{2})/([0-9]{2})/([0-9a-z]{32})(/.*)")
#用ngx.re.match就不能%d,用string.match就不能{2}，郁闷
#而且ngx.re.match所有的捕获都在m数组里，这点类似perl的m//返回。
        rewrite_by_lua '
        local date = {}
        local md5str
        local path
        date.year,date.month,date.day,date.hour,date.min,md5str,path = string.match(ngx.var.uri,"^/(%d+)/(%d+)/(%d+)/(%d+)/(%d+)/(%w+)(/%S+)")

        if date.year == nil then
             ngx.exit(404)
        end

        local time1 = tonumber(os.time(date))
        local time2 = tonumber(ngx.time())
        if md5str == ngx.md5(ngx.var.salt..date.year..date.month..date.day..date.hour..date.min..path) then
            if time2 - time1 < tonumber(ngx.var.expire) then
                ngx.req.set_uri(path)
            else
                ngx.exit(405)
            end
        else
            ngx.exit(403)
        end
        ';  
        proxy_pass         http://backend;
        proxy_set_header   Host     $host;
    }
```

然后用nginx_perl做：
```nginx
    perl_require POSIX.pm;
    perl_require Digest/MD5.pm;
    perl_set $realurl '
    sub {
        my $secret = "mysalt";
        my $expire = 600;
        my $r = shift;
        if ( $r->uri =~ m#^/(\d{4})/(\d{2})/(\d{2})/(\d{2})/(\d{2})/(\w{32})(/\S+\.mp3)#oi ) {
            my ($year, $mon, $mday, $hour, $min, $md5, $path) = ($1, $2, $3, $4, $5, $6, $7);
            my $str = Digest::MD5::md5_hex($secret . $year . $mon . $mday . $hour . $min . $path);
            my $reqtime = POSIX::mktime(00, $min, $hour, $mday, $mon - 1, $year - 1900);
            my $now = time;
            if ( $str eq $md5 and $now - $reqtime < $expire ) {
                    return $path;
            } else {
                return "error";
            };
        } else {
            return "error";
        };
    }';
   
  server { 
    location ~* \.mp3$ {
                if ($realurl = "error") { return 403; }
                proxy_pass         http://music_store_local$realurl;
                proxy_set_header   Host             $host;
    }
  }
```

然后用http_load测试单url响应情况，基本效率一样。在压力比较大(lo上跑大概200MB/s，再大就可能出错了)的情况下，第一字节响应时间大概比直接请求squid多一个数量级（从0.4ms到4ms）    
这个情况下，squid的cpu%在130％，nginx_perl的worker是25％，nginx_lua的是19％。
