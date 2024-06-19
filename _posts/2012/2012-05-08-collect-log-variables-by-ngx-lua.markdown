---
layout: post
theme:
  name: twitter
title: 通过lua统计nginx内部变量数据
category: nginx
tags:
  - lua
---

统计nginx的请求数据，一般有几个办法，一个是logrotate，通过access.log计算，这个很详细，但是实时性差一些；一个是Tengine提供的pipe，这个实时性更好，但是管道如果出现堵塞，麻烦就多了～这两种办法，归根结底都是把日志记录在本地(pipe方式如果要长期保留依然要记磁盘)然后由脚本完成计算。今天这里说另一种方法：在nginx内部，随着每次请求完成一些基础的数据统计，然后输出到存储里供长期调用。    
代码如下：

```nginx
server {
    listen 80;
    server_name photo.domain.com;

    location / {
        set $str $uri;
        content_by_lua '
            local url = ngx.var.uri
            local res = ngx.location.capture("/proxy", {vars = { str = url }})
            ngx.print(res.body)

            ngx.shared.log_dict:set("url", url)

            local upstream_stat = ngx.var.status
            local upstream_time = tonumber(ngx.var.upstream_response_time)
            local redis = require "resty.redis"
            local red = redis:new()
            local ok, err = red:connect("127.0.0.1", 6379)
            if upstream_stat ~= "200" then
                red:sadd("url",url)
                red:incr(url)
                red:incr(url..":time", upstream_time)
            end
         ';
    }
    
    location /dict_status {
        content_by_lua '
            local url = ngx.shared.log_dict:get("url")
            ngx.say(url)
         ';
    }
    
    location /redis_status {
        content_by_lua '
            local redis = require "resty.redis"
            local red = redis:new()
            local ok,err = red:connect("127.0.0.1", 6379)
            local urlist,err = red:sort("url","limit","0","1","desc","by","*")
            if not urlist then
                ngx.say(err)
                return
            end
            for i = 1, #urlist do
                local avg = red:get(urlist[i])
                local sum = red:get(urlist[i]..":time")
                ngx.say(urlist[i],"\tavg_time:",avg/sum, "\tsum:",sum)
            end
         ';
    }
    

    location /proxy {
        proxy_pass http://backend_fmn_xnimg_cn$str;
        proxy_set_header Host 'fmn.rrimg.com'; 
        include conf.d/proxy.conf;
	}
}
```

ngx_lua里的指令有set/rewrite/header_filter/log/content/access_by_lua等，它们各自处于nginx处理流程中的某一步，所以有些日志变量可能不一定都能读取到。还有header_filter和log两个不能调用subrequest和output的API(也就是只能使用上例代码中的ngx.shared.DICT方式，但只支持简单的key-value),content不能和proxy_pass在一起等等……

不过content里可以调用ngx.location.capture()来subrequest其他location，比如这里利用/proxy来完成原来的proxy_pass的功能。    
因为subrequest后$uri有变化，所以pass必须写对真正的url的全路径。这就靠之前的set $str来传递变量了。    

最终运行结果：

    # curl http://fmn.rrimg.cn/redis_status    
    /test avg_time:0.73 sum:12
