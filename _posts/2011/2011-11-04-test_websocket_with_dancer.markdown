---
layout: post
theme:
  name: twitter
title: websocket体验
date: 2011-11-04
category: dancer
tags:
  - websocket
---

因为看到mojo在宣传其内置websocket支持，去CPAN上search了一下，发现Dancer也有plugin做websocket用。稍微看了一下，很显然没看mojo的内嵌代码，而dancer的plugin代码倒是相当简单。
简单的说，就是通过AnyMQ、Plack和Web::Hippie的组合完成。注意的是，因为Web::Hippie使用了AnyEvent::Handle管理websocket的fh，AnyMQ也使用AnyEvent管理message queue，所以在启动plackup的时候，必须使用AnyEvent核心的Twiggy服务器。
Plugin里硬编码很多。比较重要的地方就是"set plack_middlewares_map"，plack_middlewares_map是dancer新加的功能，这里用URLMap来mount '/_hippie'到Web::Hippie::Pipe和AnyMQ上。也就是说，使用websocket的访问路径，必须固定为'^/_hippie/.*'这样。
然后像两个get方法，'/new_listener'和'/message'，这两个访问路径是Web::Hippie里写死的，不能改。好在一般应用也不会直接访问这个。
最后有三个register到Dancer的方法，'ws_on_message'、'ws_on_new_listener'和'ws_send'，前两个用来覆盖上面提到的get的两个route的具体信息，一般不用前面两个，因为这样就意味着页面的js里无法控制websocket了（个人理解，不知道对否？）后面那个类似把websocket改成普通的params方式请求响应（用curl/wget可以请求的那种）。
<hr>
好了，大概的机理就是这样，现在做个小东西试试看。cpanm和dancer的运用之前写过，就略过了。lib/WS_test.pm如下：
```perlpackage WS_test;
use Dancer ':syntax';
use Dancer::Plugin::WebSocket;
get '/ws' => sub {
    template 'websocket';
};
true;```
views/websocket.tt如下：
```perl
<html>
<head>
<script>
var ws_path = "ws://chenlinux.com:8080/_hippie/ws";
var socket = new WebSocket(ws_path);
socket.onopen = function() {
    document.getElementById('conn-status').innerHTML = 'Connected';
};
socket.onmessage = function(e) {
    var data = JSON.parse(e.data);
    if (data.msg)
        document.getElementById('textmsg').value += data.name + data.msg + "\n";
};
function send_msg() {
    var name = document.getElementById('name').value + ": ";
    var talk = document.getElementById('ownmsg').value;
    socket.send(JSON.stringify({ name: name,msg: talk }));
}
</script>
</head>
<body>
Connection Status: <br /><span id="conn-status"> Disconnected </span><br />
<textarea id="textmsg" cols="55" rows="10"></textarea><hr />
nickname: <input type="text" id="name" /><br />
messages: <textarea id="ownmsg"></textarea><br />
<input value="send" type=button onclick="send_msg()" />
</body>
</html>
```
ok，然后启动server就行了：
```bashsudo twiggy --listen :8080 bin/app.pl```
然后访问http://chenlinux.com:8080/ws/看看效果吧~一个小聊天室就出来了。
不过还有点问题，就是根据加入聊天室的时间先后，信息看不全……估计应该是AnyMQ的问题，个人对MQ了解不多，还需要继续看代码……

