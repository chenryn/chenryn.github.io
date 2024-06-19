---
layout: post
theme:
  name: twitter
title: 用gnuplot绘制多图
category: monitor
tags:
  - gnuplot
---
以前已经提过多次gnuplot的简便快捷了。不过大多是最基本的单图上画条线之类的。这次碰到需求，稍微help了一下在一个图上画多个区域。主要需要注意的就是set size的定位点到底从什么角度算，说实话蛮麻烦的。

上文件：

```bash
    result=$1
    begin=`head -n 1 $result.txt | awk '{print $1}'`
    end=`tail -n 1 $result.txt | awk '{print $1}'`
    cat > conf/$result.conf <<EOF
    set terminal png
    set output "png/$result.png"
    set multiplot
    set xdata time
    set timefmt "%H:%M:%S"
    set format x "%M:%S"
    set size 1.0,0.5
    set origin 0.0,0.5
    set ylabel "KRps"
    unset xtics
    plot "res/$result.txt" using 1:(\$2/1000) with points linewidth 2 title ""
    set origin 0.0,0.0
    set size 1.0,0.35
    set xtics
    set xrange ["$begin":"$end"]
    set ylabel "%usr:sys:irq"
    plot "res/$result.csv" using 2:(\$3+\$4+\$8) with boxes fs solid 1.0 title "", \
         "res/$result.csv" using 2:(\$3+\$4) with boxes fs solid 1.0 title "", \
         "res/$result.csv" using 2:3 with boxes fs solid 1.0 title ""
    set origin 0.0,0.3
    set size 1.0,0.25
    unset xtics
    set ylabel "MBps"
    plot "res/$result.csv" using 2:(\$11/1024/1024) with boxes fs solid 0.7 linecolor rgb "green" title "", \
         "res/$result.csv" using 2:(\$12/1024/1024) with lines linewidth 2 linecolor rgb "blue" title ""
    EOF
    
    cat conf/$result.conf | gnuplot
```

注意：新增了一行xrange配置，如果不指定这个几张小图的xtics会不统一，而上面两张图的xtics又已经被unset了，结果看起来就跟不同步似的。

效果如下：
![图片](/images/uploads/gnuplot-multi.png)
