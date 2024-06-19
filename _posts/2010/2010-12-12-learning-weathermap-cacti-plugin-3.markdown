---
layout: post
theme:
  name: twitter
title: weathermap-cacti-plugin学习(3)
date: 2010-12-12
category: monitor
tags:
  - cacti
  - php
---

今天继续啃weathermap的php代码，因为lib的readdata里return了$inbw和$outbw，尝试在之前理解的ReadConfig()相应match处加上了一段 `if($inbw=='0'){$this->width=0;$linematched++;}elseif`……等几分钟后cache过期，一看weathermap效果，所有的链路曲线箭头图都变成了一根直线~~然后仔细看了看这串if之前的while，发现原来weathermap不是每次针对数据进行config匹配，而是统一读取一次config。也就是说ReadConfig()里的任何修改都会对全局起作用。

既然在源头的配置参数无法修改，那么就只能在末端的绘图的时候做出改变了，找到 `draw_curve()` 函数，这个函数就是画线的。最终由 `Draw()` 函数分别调用 `calc_curve` 描点，`draw_curve` 连线，`drawlabel` 画框。`Draw()` 内容是一个顺序处理过程，在最后的 `drawlabel()` 前面，可以很清晰的看到 `$task[*]` 是怎么取出的：
```php
$outbound=array($q1_x,$q1_y,0,0,$this->outpercent,$this->bandwidth_out,$q1_angle);
$inbound=array($q3_x,$q3_y,0,0,$this->inpercent,$this->bandwidth_in,$q3_angle);
```
那么在draw_curve()前面，依葫芦画瓢来上一段就好了：
```php
if(($this->bandwidth_out == '0') && ($this->bandwidth_in == '0'))
{
    $link_width='0';
}
else
{
    $link_width=$this->width;
}
draw_curve($im, $this->curvepoints, $link_width, $outline_colour, $comment_colour, array($link_in_colour, $link_out_colour), $this->name, $map);
```

这个改完当然不能看到效果，看到就该排障去了~不过可以采用一点变通的方法来验证一下，比如某些线路现在比较空闲，我们就把预定的阀值0（断网的流量）改大一些，刚好超过某个空载线路即可了：

比如改成 `if ( $this->bandwidth_out < '1000' )` 的话，weathermap效果变成如下：

![wethermap](/images/uploads/qqe688aae59bbee69caae591bde5908d.jpg)

其中两条流量小于1000bits的线路，其width就变成了0，只留下一条直线了~~

至于为了 `width==0` 却还留下了一条线，这就跟weathermap的绘图方式有关了。`draw_curve` 中是这么利用gd画图的：

1. 根据node的位置，获取在二维空间上的x轴、y轴坐标，在两个node之间通过打点的方式进行矢量连线；
2. 获取设定的width，将之前的坐标点平移相应的位置，再次打点；
3. 在连线的中点处绘制箭头；
4. 填充颜色。

如果要完全去除掉这根连线，或许可以在 `draw_curve` 中设定其连线长度为0？在 `draw_curve()` 中有一个变量叫 `$totaldistance`，指的是两个node之间的距离，之后包括箭头、文字等，都是以这个变量\*50%来计算的。添加 `if($this->bandwidth_out<1000){$totaldistance=0}`，等了十分钟再刷新，可图片依然没有更新！

继续看 `$totaldistance` 是怎么得出的，看到了 `$this->curvepoints`，而 `$this->curvepoints` 是通过 `calc_curve($xpoints, $ypoints)` 返回的。那么在 `Draw()` 中继续修改 `$this->curvepoints` 即可。变通一下上面的测试代码如下：
```php
$link_width=$this->width;
$this->curvepoints = calc_curve($xpoints, $ypoints);
if ( $this->bandwidth_out < '2000' )
{
    $link_width=0; //没有连线的话，宽度设啥都一样了~
    $this->curvepoints = array( );
}
```
稍后刷新页面，看到原来的连线已经不见了~ 不过从效果图来看，少了连线反而不起眼了，还不如留着一根线容易引起警觉……

![new-weathermap](/images/uploads/qqe688aae59bbee69caae591bde5908d1.jpg)

