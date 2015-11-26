---
layout: post
title: squid自动配置web化
date: 2010-01-23
category: CDN
tags:
  - squid
  - web
  - bash
---

[root@test data]# cat index.htm
```html
<html>
<head>
<title>饶琛琳专用21V-CDN流程系统</title>
<style type="text/css">
.style1 {
text-align: center;
}
</style>
</head>

<body>
<center>
<h1>Designed for support@21vianet.com in RT table.</h1>
<hr>
<form method="post"  action="/cgi-bin/rt.cgi">
<table>
<tr>
<td colspan="2">
<textarea name="config" style="width: 700px; height: 200px" rows="1" cols="20" onmouseover="focus()" onfocus="if(value=='在此填入squid配置，或者者测试url，注意分行哟') {value=''}" onmouseout="blur()" onblur="if (value=='') {value='在此填入squid配置，或者测试url，注意分行哟'}">在此填入squid配置，或者测试url，注意分行哟</textarea></td>
</tr>
<tr>
<td>
<textarea name="iplist" style="width: 200px; height: 250px" rows="1" cols="20" onmouseover="focus()" onfocus="if(value=='在此填入服务器组IP，注意绵阳、广州、汕头网通没VPN哈') {value=''}" onmouseout="blur()" onblur="if (value=='') {value='在此填入服务器组IP，注意绵阳、广州、汕头网通没VPN哈'}">在此入服务器组IP，注意绵阳、广州、汕头网通没VPN哈</textarea></td>
<td>
<input name="custom" type="text" style="width: 246px" value="在此填入客户简称" onfocus="if(value=='在此填入客户简称') {value=''}" onblur="if (value=='') {value='在此填入客户简称'}" />
<br />
<input name="action" type="radio" value="add" />添加该客户加速配置<br />
<input name="action" type="radio" value="del" />删除该客户加速配置<br />
<input name="action" type="radio" value="change" />更新该客户加速配置<br />
<input name="action" type="radio" value="conf" />检查配置统一性<br />
<input name="action" type="radio" value="wget" />wget方式检查（https等特殊情况推荐）<br />
<input name="action" type="radio" value="curl" checked="checked" />curl方式检查（防盗链、过期时间推荐）<br />
<input name="submit" type="submit"/></td>
</tr>
</table>
</form>
</center>

<div id="ShowAD" style="position:absolute;z-index:100;font-size:12px">
<div style="width:135;height:18px;font-size:14px;font-weight:bold;text-align:left;cursor:hand;" onClick="closead();"><font color="ff0000">升级特性</font>
v0.1.0:配置文件存入中心，调用脚本conf.sh运行；<br>
v0.1.1:新增wget测试功能，采用hosts绑定方式；<br>
v0.2.0:新增curl测试、配置文件校对功能，采用指定代理参数，避免修改hosts权限问题；<br>
v0.3.0:更新配置分发功能，直接逐句插入；<br>
v0.3.1:加强wget和curl测试定制功能，支持HTTPS、防盗链、过期时间检查；<br>
v0.3.2:支持url批量测试；<br>
v0.3.3:加强输入IP自动识别；<br>
更多精彩，敬请期待~~<br>

<script language="javascript">
var bodyfrm = ( document.compatMode.toLowerCase()=="css1compat" ) ? document.documentElement : document.body;
var adst = document.getElementById("ShowAD").style;
adst.top = ( bodyfrm.clientHeight -300-22 ) + "px";
adst.left = ( bodyfrm.clientWidth -200 ) + "px";
function moveR() {
adst.top = ( bodyfrm.scrollTop + bodyfrm.clientHeight - 300-22) + "px";
adst.left = ( bodyfrm.scrollLeft + bodyfrm.clientWidth - 200 ) + "px";
}
setInterval("moveR();", 80);
function closead()
{
adst.display='none';
}
</script>

</body>
</html>
```
[root@BeiJingBGP-Dns-02 cgi-bin]# cat rt.cgi
```bash
#!/bin/bash
function filter(){
sed '{
s/%23/#/g;
s/%0D%0A/n/g;
s/%5E/^/g;
s/%3A/:/g;
s/%2F///g;
s/%28/\(/g;
s/%7C/\|/g;
s/%29/\)/g;
s/%24/$/g;
s/%25/%/g;
s/%3F/?/g;
s/%3D/=/g;
s/%5C/\/g;
}' $1
}

function regulate(){
sed "{
1i#$custom
$a#$custom+end
$!N; /^(.*)n1$/!P;D
}" $1
}

function uniform(){
awk -F"[+| ]" '{
for(i=1;i<=NF;i++){
if($i~/[0-9]+.[0-9]+.[0-9]+.[0-9]+/){
print $i
}
}
}'
}

echo "Content-type:text/html"
echo ""
echo "<html>"
if [ "$REQUEST_METHOD" = "POST" ] ; then
QUERY_STRING=`cat -`
fi

#echo "<center>$QUERY_STRING</center>"
action=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $8}'`
custom=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $6}'`
iplist=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $4}'|filter|uniform`

case $action in
add)
ref_conf=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $2}'|filter|regulate|sed '1!G;h;$!d'`
#echo "$ref_conf"
for ip in $iplist;do
ping -c 3 $ip|awk -F, '/loss/{print $3}'
for ref in $ref_conf;do
echo "$ref<br>"
/usr/local/bin/sshpass -p 123456 ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no <a href="mailto:root@$ip">root@$ip</a> sed -i "/config/a\`echo $ref|sed 's/+/\ /g'`" /home/squid/etc/squid.conf &amp;&amp; /home/squid/sbin/squid -k reconfigure
done
done
;;
wget)
test_url=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $2}'|filter`
for ip in $iplist;do
for url in $test_url;do
domain=`echo $url|awk -F/ '{print $3}'`
echo "$ip $domain" > /etc/hosts
wget -S -O /dev/null "$url" -o wget.log --no-check-certificate -t 1
cat wget.log|awk 'BEGIN{ORS="<br>"}1'
done
done
;;
curl)
test_url=`echo $QUERY_STRING|awk -F"[=|&amp;]" '{print $2}'|filter`
for url in $test_url;do
echo "##################################<br>"
echo "###$url<br>"
for ip in $iplist;do
domain=`echo $url|awk -F/ '{print $3}'`
echo "##############<br>"
echo "$ip<br>"
curl -I -x $ip:80 -A "support/RT (21V-CDN)" -e "<a href="http://$domain/">http://$domain</a>" "$url"|awk 'BEGIN{ORS="<br>"}/HTTP/1|Cache|Age/'
sleep 1;
done
done
;;
*)
echo '<head><META HTTP-EQUIV="refresh" Content="0;URL=http://1.2.3.4/index.htm"></head>'
;;
esac

echo "</html>"
```
