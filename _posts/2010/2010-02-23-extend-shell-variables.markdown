---
layout: post
title: shell变量扩展
date: 2010-02-23
category: bash
---

第一种扩展形式，按长度截取：${PARAMETER:OFFSET:LENGTH}；例：

i=http://www.baidu.com/a/b.html;j=${i:1:10};echo $j
ttp://www.

第二种扩展形式，按模式截取：${PARAMETER#WORD}、${PARAMETER##WORD}、${PARAMETER%WORD}、${PARAMETER%%WORD}；例：

i=http://www.baidu.com/a/b.html;b=${i%/*};a=${i%%/*};c=${i#*/};d=${i##*/};echo $b;echo $c;echo $d;echo $a
http://www.baidu.com/a
/www.baidu.com/a/b.html
b.html
http:

第三种扩展形式，按模式替换：${PARAMETER/PATTERN/STRING};${PARAMETER//PATTERN/STRING}，例：

i=http://www.baidu.com/a/b.html;x=${i/baidu/google};y=${i//?a/xyz};echo $x;echo $y
http://www.google.com/a/b.html
http://www.xyzidu.comxyz/b.html

第四种扩展形式，指定默认值：${PARAMETER:-WORD}、${PARAMETER:+WORD}、${PARAMETER:?WORD}、${PARAMETER:=WORD}，例：

unset x;y="abc def"; echo "/${x:-'XYZ'}/${y:-'XYZ'}/$x/$y/"
/'XYZ'/abc def//abc def/

unset x;y="abc def"; echo "/${x:='XYZ'}/${y:='XYZ'}/$x/$y/"
/'XYZ'/abc def/'XYZ'/abc def/

( unset x;y="abc def"; echo "/${x:?'XYZ'}/${y:?'XYZ'}/$x/$y/" )  >so.txt 2>se.txt
cat so.txt
cat se.txt
-bash: x: XYZ

unset x;y="abc def"; echo "/${x:+'XYZ'}/${y:+'XYZ'}/$x/$y/"
//'XYZ'//abc def/

说明：-返回默认值，但不更改变量本身；=返回默认值同时更改变量为默认值；?返回默认值到标准错误；+与-相反。

