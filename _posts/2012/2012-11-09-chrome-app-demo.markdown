---
layout: post
theme:
  name: twitter
title: Chrome的APP简单用法
category: web
tags:
  - chrome
---
学习一下简单的chrome app写法。首先，chrome的ext和web app和packaged app就要分清楚。简单说，ext就是可以出现在地址栏右侧的，app是可以出现在任务栏右侧的。而web app其实就是用json描述了一个url地址，packaged app则是最接近普通桌面程序的，需要完整的带有html/css/js等内容。但同时，因为packaged app可以在关闭chrome浏览器后运行，所以有些浏览器上的API它也用不了。

首先上一个web app的demo，只要一个manifest.json在本地就够了。关键点是app里指定为url，permissions指定需要的权限。

```javascript
{
  "name": "WebApp",
  "version": "0.1",
  "app": {
    "urls": [ "http://www.domain.com/chrome/" ],
    "launch": {
      "web_url": "http://www.domain.com/chrome/index.html"
    }
  },
  "permissions": ["background", "notifications"],
  "manifest_version": 2
}
```

然后余下的事情就是web上的了。在`http://www.domain.com/chrome/index.html`里定义内容。比如我这是这样：

```html
<html><head></head>
<body>
<button id="openBackgroundWindow">开启后台运行</button>
<button id="closeBackgroundWindow">关闭后台运行</button>
<script src="index.js"></script>
</body>
</html>
```

然后把事情交给index.js来完成。这也是chrome app的通常做法，尽量拆分干净，尤其到packaged app的时候，压根就不让你在html里写script了。index.js如下：

```javascript
var bgWinUrl = "background.html#yay";
var bgWinName = "bgNotifier";

function openBackgroundWindow() {
  window.open(bgWinUrl, bgWinName, "background");
}

function closeBackgroundWindow() {
  var w = window.open(bgWinUrl, bgWinName, "background");
  w.close();
}

document.addEventListener('DOMContentLoaded', function() {
  document.querySelector('#openBackgroundWindow').addEventListener(
    'click', openBackgroundWindow);
  document.querySelector('#closeBackgroundWindow').addEventListener(
    'click', closeBackgroundWindow);
});
```
注意到这里的`background.html`加了锚点，原因我懒得看英文说明了，反正大意是不写个锚点有时候会出问题。

最后是background.html，内容参见之前博客里写的juggernaut。简单几十行。一个可以不再打开具体页面自动收报警消息的app就改造出来了～～

这时候进一步折腾的想法就出来了：既然叫app嘛，功能应该多一点，不单收报警，还能存下来，这样出去一趟回来可以看离线记录。

下面就说离线的packaged app。

`manifest.json`的app里就不能写urls要写background了。文档中说background可以写scripts或者page，但是我实验发现scripts正常page不起作用(也确实不报错)。
```javascript
{
  "name": "Packaged App",
  "version": "0.1",
  "app": {
    "background": {
      "scripts": ["juggernaut.js", "filesystem.js", "background.js"]
    }
  },
  "permissions": ["background", "notifications", "unlimitedStorage"],
  "manifest_version": 2
}
```
chrome app会自动把scripts数组`依次`加载。
这里需要注意修改一下默认的juggernaut/application.js，因为chrome packaged app没有浏览器框架，所以disconnect那有个报错，删除掉那三行即可。
然后background.js里最常见的功能是当点击app的时候弹出的页面，代码如下：
```javascript
chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('main.html', {
    'width': 400,
    'height': 500,
    //frame: 'none'
  });
});
```
如果css够好，可以开启`frame: none`，然后页面看不到一丝浏览器的样子，你就可以做得跟真的app一样有自己的控制了。

然后是文件操作。html5有file api。所以可以直接操作文件了：
```javascript
window.webkitRequestFileSystem(window.TEMPORARY, 5*1024*1024, function (fs) {
    fs.root.getFile("syslog.txt", {create: true}, function(fileEntry){
        fileEntry.createWriter(function(fileWriter){
            var bb = new Blob(["New File Ready\n"], {type: 'text/plain'});
            fileWriter.write(bb);
        }, errorHandler);
    }, errorHandler);
}, errorHandler);

function append_file(msg) {
    window.webkitRequestFileSystem(window.TEMPORARY, 5*1024*1024, function (fs) {
        fs.root.getFile("syslog.txt", {create: false}, function(fileEntry){
            fileEntry.createWriter(function(fileWriter){
                fileWriter.seek(fileWriter.length);
                var bb = new Blob([msg], {type: 'text/plain'});
                fileWriter.write(bb);
            }, errorHandler);
        }, errorHandler);
    }, errorHandler);
};
```
这里大多数网上的例子都还是用的`BlobBuilder()`，经过我试验，至少在chromium version24上，已经没有这个API了。

这里注意一个问题：Juggernaut同时收到多条消息，调用append_file()的话，会有文件锁问题。所以我加上一个缓冲控制：
```javascript
var message = '';
setInterval(function() {
    if ( message ) {
        append_file(message);
        message = '';
    }
}, 60000);
jug.subscribe("syslog", function(data){
    var msg = data.join('|') + "\n";
    message += msg;
    ...
    notification.show();
});
```
后台的工作大概就是这些。然后是弹出的main.html。记住之前提到的，不能在里面写js。所以html里除了写个div啥都没有，功能依然交给main.js来做：
```html
<html>
<head>
<meta charset="utf-8" />
<title>Storage test</title>
<script src="main.js"></script>
</head>
<body>
<div id="bar">
    <form id="form">
        <button id="reload-window-button">刷新</button>
        <button id="remove-window-button">清空</button>
        <button id="close-window-button">关闭</button>
    </form>
</div>
<div id='log'>
    <ul id='msg'>
    </ul>
</div>
</body>
</html>
```
不过关于刷新页面的问题现在还比较茫然，试过metadata/reload/location.href等各种办法，都不起作用，只能在页面上右键选择刷新……
```javascript
onload = function() {
    var channel_file = 'syslog.txt';
    window.webkitRequestFileSystem(window.TEMPORARY, 5*1024*1024, function (fs) {
        fs.root.getFile(channel_file, {}, function(fileEntry) {
            fileEntry.file(function(file) {
            var reader = new FileReader();
            reader.onloadend = function() {
                var logul = document.getElementById('log');
                var logli = document.createElement('li');
                logli.innerText = this.result;
                logul.insertBefore(logli, logul.firstChild);
            };
            reader.readAsText(file);
            }, errorHandler);
        }, errorHandler);
    }, errorHandler);

    document.getElementById("remove-window-button").onclick = function() {
        window.webkitRequestFileSystem(window.TEMPORARY, 5*1024*1024, function (fs) {
            fs.root.getFile(channel_file, {create: false}, function(fileEntry){
                fileEntry.remove(function(){
                    fs.root.getFile(channel_file, {create: true}, function(fileEntry){
                        fileEntry.createWriter(function(fileWriter){
                            var bb = new Blob(["Clean Over\n"], {type: 'text/plain'});
                            fileWriter.write(bb);
                        }, errorHandler);
                    }, errorHandler);
                }, errorHandler);
            }, errorHandler);
        }, errorHandler);
    }
    document.getElementById("close-window-button").onclick = function() {
        window.close();
    }
    document.getElementById("reload-window-button").onclick = function() {
        window.location.reload(true);
    }
};
```

以上。

最后，如果完成了，在浏览器上直接选择打包即可。不过新版本的chrome已经不再允许直接安装非web store的crx了……
