---
layout: post
theme:
  name: twitter
title: juttle 可视化界面介绍
category: logstash
tags:
    - elasticsearch
    - javascript
    - nodejs
---

上篇介绍了一下怎么用 juttle 交互式命令行查看表格式输出。juttle 事实上还提供了一个 web 服务器，做数据可视化效果，这个同样是用 juttle 语言描述配置。

我们已经在上一篇安装好了 `juttle-engine` 模块，那么直接启动服务器即可：

```
~$ juttle-engine -d
```

然后浏览器打开 `http://localhost:8080` 就能看到页面了。注意，请使用 Chrome v45 以上版本或者 Safari 等其他浏览器，否则有个 Array 上的 bug。

但是目前这个页面上本身不提供输入框直接写 juttle 语言。所以需要我们把 juttle 语言写成脚本文件，再来通过页面加载。

```
~$ cat > ~/test.juttle <<EOF
read elastic -index 'logstash-*'  -from :-2d: -to :now: 'MacBook-Pro'
  | reduce -every :1h: count() by 'path.raw'
  | (
      view timechart -row 0 -col 0;;
      view table -height 200 -row 1 -col 0;
      view piechart -row 1 -col 0;
  );
(
  read elastic -index 'logstash-*'  -from :-2d: -to :-1d: 'MacBook-Pro' AND '/var/log/system.log'
    | reduce -every :1h: count();
  read elastic -index 'logstash-*'  -from :-1d: -to :now: 'MacBook-Pro' AND '/var/log/system.log'
    | reduce -every :1h: count();
)
  | (
      view timechart -duration :1 day: -overlayTime true -height 400 -row 0 -col 1 -title 'syslog hour-on-hour';
      view table -height 200 -row 1 -col 1;
  );
EOF
```

然后访问 `http://localhost:8080?path=/test.juttle`，注意这里的path参数的写法，这个/其实指的是你运行 `juttle-engine` 命令的时候的路径，而不是真的设备根目录。

就可以在浏览器上看到如下效果：

![](/images/uploads/juttle-viz.png)

页面上还有一行有关 `path.raw` 的 WARNING 提示，那是因为 juttle 目前对 elasticsearch 的 mapping 解析支持的不是很好，但是不影响使用，可以不用管。

## 可视化相关指令介绍

我们可以看到这次的 juttle 脚本，跟昨天在命令行下运行的几个区别：

1. 我们用上了 `()`，这是 juttle 的一大特技，对同一结果并联多个 view ，或者并联多个输入结果做相同的后续处理等等。
2. 我们对 view 用上了 `row` 和 `col` 参数，用来指定他们在页面上的布局。
3. 有一个 `timechart` 我们用了 `-durat  :1d: -overlayTime true` 参数。这是 `timechart` 独有的参数，专门用来实现同比环比的。在图上的效果大家也可以看到了。不过目前也有小问题，就是鼠标放到图上的时候，只能看到第二个结果的指标说明，看不到第一个的。

