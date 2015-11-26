---
layout: post
title: 用gnuplot绘制直方图 
category: monitor
tags:
  - gnuplot
---
越来越喜欢用 gnuplot 画图了，因为有时候发现自己实在是不会用 Excel……

之前基本上用gnuplot画的都是时间轴形式的，诸位客官肯定已经看多了。但是 gnuplot 可不止是这点。还有一种很常见的功能也很方便，就是与时间无关的多个数据做对比的时候，还画成两条连线，就不如画成直方图更体现价值了。比如下面这组数据：

    地区	总数(A)	总数(B)
    美洲	16682	20344
    澳洲	4021	3672
    欧洲	2902	2878

只需要几行配置，就可以生成很漂亮滴直方图对比了。

```bash
set key right top Left reverse width 0 box 3
set xlabel "各大洲区域"
set ylabel "请求总数"
set ytics 0, 500
set mytics 5
set grid
set boxwidth 0.9 absolute
set style fill solid 1.00 border -1
set style histogram clustered gap 1 title offset character 0, 0, 0
set style data histograms
set terminal png size 1024, 512
set output "oversea.png"
plot 'oversea.csv' using 2:xtic(1) ti col, '' u 3 ti col
```

注意如果行比较多，默认大小的图上X轴的标记就会挤在一块了，所以在 set terminal 后面设置图片大小，这和 set size 是不一样的。后者设置的相对值是本次要 plot 的图形在总画布上的比例大小。

plot 里 using 的两列也是和画 line 图时反过来的顺序，而且 X 轴的列要用 xtic() 包起来写，否则 gnuplot 会认为这应该是个自增序列，然后找不到 xrange 出错。

效果图如下：

![图片](/images/uploads/gnuplot-boxes.png)
