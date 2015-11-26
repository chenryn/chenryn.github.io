---
layout: post
title: url_rewrite_program（squid游戏恶搞~）
date: 2009-12-30
category: squid
---

标题很引人吧。其实是我在查找squid的rewrite资料时，看到的一篇文章。原作者突发奇想，准备让公司的同事们上网时，看到的所有图片全都倒过来180°。嘿嘿，小样，还不拧断你们脖子~~

当然这么个大计划，单靠squid还是不行的，得后台配合一下web服务器才行。

原理是这样的：squid每接到一个请求，首先判断后缀名是不是图片类型，如果是，下载到web服务器目录，然后调用程序颠倒图片，拷贝去另一个发布路径下。最后把新的路径返回给squid，交给浏览器去看。

假设下载目录是/revimg，发布目录是/revimg/out，那么apache里配置如下vhost：
```apache
ServerName revimg.soulogic.com
DocumentRoot /revimg/out
```
好了，其他准备完成。进入squid部分：

squid官方并没有转向的设定，不过他允许甚至推荐了一些转向外挂（好吧，说好听些，第三方插件）。只需要很简单的在squid.conf里启用url_rewrite_program（也叫redirect_program）就可以了：

url_rewrite_program /etc/squid/redirect.php（常见的是pl、py，当然也可以是squirm、squidGuard等软件，其实只要是squid属主可执行文件，parse都能通过）

根据需要，还有相关的children、access、host配置。
下面是原作者提供的php代码。很赞，可惜还没看懂，慢慢品味：
```php
#!/usr/bin/php
<?PHP
chdir("/revimg");
$sServer = "revimg.soulogic.com";
while ($sContent = fgets(STDIN) ) {
    $sContent = trim($sContent);
    if (empty($sContent)) {
        continue;
    }
    $aArg = explode(" ", $sContent, 5);
    $sURL = $aArg[0];
    if ($aArg[3] != "GET") {
        fwrite(STDOUT, $sURL."n");
        continue;
    }
    $aURL = parse_url($sURL);
    $aURL += array("scheme" => "", "host" => "", "path" => "");
    if ($aURL["scheme"] != "http"
        || $aURL["host"] == $sServer
        || !preg_match("/^[0-9a-z\-]+(\.[0-9a-z\-]+)+(:[0-9]{2,5})?$/i", $aURL["host"])
        || !preg_match("/\.(jpg|jpeg|png|gif)$/i", $aURL["path"])
    ) {
        fwrite(STDOUT, $sURL."n");
        continue;
    }
    // 检测通过，处理图片
    $sHash = md5($sURL);
    $sDir  = substr($sHash, 0, 2)."/".substr($sHash, 2, 2);
    $sFile = $sDir."/".substr($sHash, 4);
    $sFileOut = "out/".$sFile;
    if (!file_exists($sDir)) {
        mkdir($sDir, 0777, TRUE);
        mkdir("out/".$sDir, 0777, TRUE);
        chmod("out", 0777);
        chmod("out/".substr($sHash, 0, 2), 0777);
        chmod("out/".$sDir, 0777);
    }
    if (!file_exists($sFile)) {
        $sCmd = "wget -qc ".escapeshellarg($sURL)." -O ".$sFile;
        exec($sCmd);
    }
    if (!file_exists($sFileOut)) {
        $sCmd = "convert ".$sFile." -flip -quality 80 ".$sFileOut;
        exec($sCmd);
        chmod($sFileOut, 0666);
    }
    $sURL = "<a href="http://&quot;/">http://"</a>.$sServer."/".$sFile;
    fwrite(STDOUT, $sURL."n");
}
?>
```
原作者说：squid在重定向处理是采用的标准输入输出方式，所以测试的时候只需要cat test.txt|/etc/squid/redirector.php就可以了。
这个东东还能进一步优化。因为图片在浏览器本地也有缓存的，如果之前同事们已经上过，怎么办？还得改写Expires。
