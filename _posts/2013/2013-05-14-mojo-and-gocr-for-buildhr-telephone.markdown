---
layout: post
theme:
  name: twitter
title: 用mojo抓取数据并gocr替换图片内容
category: perl
---
现在的网站越来越狡猾，连招聘网站的信息都懂的把公司的联系方式动态图片化了。还好为了观看方便，没加什么干扰。所以写个脚本来识别还是可以的。虽然到目前为止没发现比较好的 OCR 工具——我指的是可以直接apt-get安装的，有朋友知道哪个比较好的话，欢迎告诉我~

尝试了一下 tesseract-ocr 和 gocr ，还是 gocr 靠谱一点点。所以 `apt-get install gocr` 安装然后运行下面这个 Perl 脚本：

```perl
use ojo;
use 5.010;
g("http://search.buildhr.com/job/581968.html")->dom->charset("UTF-8")->find("div .postjob .padding")->[-1]->find("p")->each(sub{
    my $line = shift;
    my $img_element = $line->at('img');
    if (defined $img_element) {
        my $img_url = $img_element->{src};
        g($img_url)->content->asset->move_to("test.jpg");
        my $seem_str = `gocr test.jpg`;
        chomp($seem_str);
        say join($seem_str, split(/ /, $line->text));
    }
});
```

不过老是把 `7` 识别成 `_`。

真是越来越觉得 ojo 好用啊~
