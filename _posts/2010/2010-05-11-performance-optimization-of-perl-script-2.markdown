---
layout: post
theme:
  name: twitter
title: perl脚本性能优化（续）
date: 2010-05-11
category: perl
---

上回提到，性能优化的四个回答，今天在扶凯的博客里看到一篇文章，刚好是同样情况下的流程优化。按照其中的说法，修改测试，果然改进很大：

优化的地方在这里：

-:foreach (sort keys %url_table) {
+:if(exists $url_table{$1}) {
print LIST_FH "$_n";}

在将所有的url写入散列后，一般的处理办法是用keys检索哈希表，而其实只需要判定存在，直接输出即可。
然后分别用time测试四个脚本，结果如下：

    长正则，检索哈希——1.882s
    短正则，检索哈希——1.543s
    长正则，判定输出——0.804s
    短正则，判定输出——0.651s
