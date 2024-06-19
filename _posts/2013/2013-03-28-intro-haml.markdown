---
layout: post
theme:
  name: twitter
title: Haml 简介
---
Haml 是 Ruby 社区的一种 HTML 标记语言，它利用强制缩进和类似 jQuery 属性标签的风格，简化书写 HTML 的工作。文档见：<http://haml.info/docs.html>。

下面是一段官网上的快速入门，从标准的 erb 模板转变成 haml 模板：

```ruby
<div id='content'>
  <div class='left column'>
    <h2>Welcome to our site!</h2>
    <p><%= print_infomation %></p>
  </div>
  <div class='right' id='item<%= item.id %>'>
    <%= render :partial => "item" %>
  </div>
</div>
```

用 haml 只用这么写：

```ruby
#content
  .left.column
    %h2 Welcome to our site!
    %p= print_information
  .right{:id => "item#{item.id}"}
    = render :partial => "sidebar"
```

看起来相当 cool，回头在 CPAN 上一翻，原来 perl 社区也有 port 过来的 [Text::Haml](https://metacpan.org/module/Text::Haml) 了。根据 perl 的特点有所改变，但是省键盘的特点依然在。

下面是一个例子：
```perl
use Text::Haml;
my $haml = Text::Haml->new();
my $hash = {
    title => 'my title',
    content => { line1 => "test", line2 => "test2" }
};
print $haml->render_file('test.haml', %$hash);

```

`test.haml` 如下：

```perl
%html{ :xmlns => "http://www.w3.org/1999/xhtml", :lang => "zh"}
  %head
    %title= $title
  %body
    #content
      .container
        %strong= $title
        - for my $line ( keys %$content ) {
            .row-fluid= $content->{$line}
        - }
```

生成的 HTML 内容如下：

```html
<html xmlns='http://www.w3.org/1999/xhtml' lang='zh'>
  <head>
    <title>my title</title>
  </head>
  <body>
    <div id='content'>
      <div class='container'>
        <strong>my title</strong>
          <div class='row-fluid'>test</div>
          <div class='row-fluid'>test2</div>
        
      </div>
    </div>
  </body>
</html>
```

Text::Haml 还提供了一个初始化参数 `vars_as_subs`，可以把变量变成同名函数，这样写起来就更像 ruby 了。不过目前只能是纯变量，复杂语句还是不行，所以好看不中用……

Text::Haml 向 Text::Xslate 学习，也提供了  `cache_dir`, `filter` 等等功能，所以性能和功能方面应该也不差。

[Template::Tookit](https://metacpan.org/module/Template::Tookit) 也有插件 [Template::Plugin::Haml](https://metacpan.org/module/Template::Plugin::Haml) 可以参看。

### wrapper.tt
```perl
!!! 5
%html
[% content %]
```

### hello.tt
```perl
[%- message='Hello World' %]
[%- USE Haml -%]
[%- WRAPPER wrapper.tt | haml -%]
[%- FILTER haml -%]
 %head
  %meta{:charset => "utf-8"}
  %title hello
 %body
  %p [% message %]
  %ul
  [%- total=0; WHILE total < 5 %]
   %li [% total=total+1 %][% total %]
  [%- END -%]
[%- END -%]
```

perl 三大 web 框架 Catalyst/Mojo/Dancer也都有对应的模板插件。
