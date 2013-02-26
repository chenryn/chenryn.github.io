---
layout: post
title: 把docx文档转换成markdown格式发布
tags:
  - ruby
---

有些Word文档想搬到博客上来，而博客用的是markdown的格式。最简单的办法是在Word里转成html格式另存为，因为markdown和html是兼容的。不过word直接另存为的html里面带有“海量”的无聊样式，实在不方便之后我们再用vim的工具编辑。所以还是想办法整整。

相对来说，Word的docx格式比doc格式要容易处理，因为docx是微软特意推出的open xml格式。其实就是记录了文本内容的content.xml、附件media/\*和对应附件路径的\_ref.xml等的zip包而已。所以相对必须在Windows平台上调用WIN32OLE的API来处理的doc来说，我们在linux平台上也可以很容易的处理docx文件了。比如rubygems上就有一个很不错的gem叫`ydocx`。一般的docx库都是只抽取docx里的content文字，而这个ydocx很负责的把media/\*也复制到docxname\_files/images/\*下面，并且在html里生成`<img>`标签了。

然后另一步就是把html转换成markdown，这在github上也有现成的repo叫[downmark\_it](https://github.com/cousine/downmark_it)。嗯，这名字一目了然就是反过来……

(`ydocx`用的是`nokogiri`，`downmark\_it`用的是`hpricot`，或许应该也改用`nokogiri`比较好~不过`nokogiri`官网可耻的被墙了)

# 首先安装依赖

{% highlight bash %}
  apt-get install libxslt1-dev libxml2-dev
  gem install rubyzip htmlentities rmagick ydocx hpricot
  wget https://raw.github.com/cousine/downmark_it/master/downmark_it.rb
{% endhighlight %}

# 编写转换脚本

{% highlight ruby %}
  require 'rubygems'
  require 'ydocx'
  $: << File.dirname(__FILE__)
  require 'downmark_it'
  filename = ARGV.shift
  ydocx = YDocx::Document.open(filename)
  html = ydocx.to_html.gsub(/\n/, '')
  puts DownmarkIt.to_markdown(html)
{% endhighlight %}

这样就能看到输出了。目录里的每个章节都有引用格式凸现，美中不足是对word里的标题样式识别不太好，本来期望是可以自己生成`<h1>`、`<h2>`的，但是ydocx生成的html里只把第一个标题一变成`<h1>`，其他的都是普通的`<p>`。

另一个问题是上面脚本里直接调用to_html的方法，不会保存住unzip出来的images文件夹。自己再另写一段unzip的代码:

{% highlight ruby %}
  require 'fileutils'  
  require 'zip/zip'  
  require 'zip/zipfilesystem'  
    
  def unzip(zip_file, dest_dir)
    Zip::ZipFile.open(zip_file) do |zf|
      zf.each do |e|
        path = File.join(dest_dir, e.name)
        FileUtils.mkdir_p(File.dirname(path))
        zf.extract(e, path) { true }
      end  
    end  
  end
  dirname = File.basename(filename, '.docx')
  unzip(filename, "/tmp/#{dirname}")
  FileUtils.mv("/tmp/#{dirname}/media/", "/images/")
  FileUtils.rm_rf("/tmp/#{dirname}")
{% endhighlight %}

比较普通的办法，是直接使用ydocx自带的脚本`docx2html --format none file.docx`，会在docx文档的同级目录下生成同名html和_files目录。然后再写一个单行脚本转成markdown的。
