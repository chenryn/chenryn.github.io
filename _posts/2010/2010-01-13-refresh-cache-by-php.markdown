---
layout: post
title: 刷新squid缓存的php脚本
date: 2010-01-13
category: CDN
tags:
  - php
  - squid
---
```php
<?php
interface Flush_Cache
{
    public function flush($url);
}
class Flush_Cache_HTTP_Header_Impl implements Flush_Cache
{
    public function flush($url)
    {
        if(empty($url))
        {
            return;
        }
        $url_component = parse_url($url);
        global $g_squid_servers;
        foreach ($g_squid_servers as $server)
        {
            $squid_params = split(':' , $server);
            $fsocket = fsockopen($squid_params[0], intval($squid_params[1]), $errono, $errstr, 3);
            if(FALSE != $fsocket)
            {
                $head = "HEAD {$url_component['path']} HTTP/1.1rn";
                $head .= "Accept: */*rn";
                $head .= "Host: {$url_component['host']}rn";
                $head .= "Cache-Control: no-cachern";
                $head .= "rn";
                echo $head;
                fwrite($fsocket , $head);
                while (!feof($fsocket))
                {
                    $line = fread($fsocket , 4096);
                    echo $line;
                }
                fclose($fsocket);
            }
        }
    }
}
$g_squid_servers = array('192.168.2.88:80');
$flush_cache = new Flush_Cache_HTTP_Header_Impl();
$flush_cache->flush('http://ent.cdqss.com/index.html');
?>
```

