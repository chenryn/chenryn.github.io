---
layout: post
title: RT故障处理操作一例
date: 2011-02-24
category: database
tags:
  - MySQL
  - perl
---

公司RT系统某工单页面无法打开。通过httpwatch发现是图片附件比较大，卡住了页面加载最终导致。
询问当事人后，决定把图片删除掉。
右键菜单查看图片url，是http://rt.domain.com/Ticket/Attachment/123456/654321/12.jpg这样的格式~
于是在服务器的DocumentRoot下查找相关路径，发现Ticket/Attachment下只有一个文件dhandler，这是一段perl程序。
相关部分如下：
{% highlight perl %}my $arg = $m->dhandler_arg;                # get rest of path
if ($arg =~ '^(\d+)/(\d+)') {
$trans = $1;
$attach = $2;
}
my $AttachmentObj = new RT::Attachment($session{'CurrentUser'});
$AttachmentObj->Load($attach) || Abort("Attachment '$attach' could not be loaded");
unless ($AttachmentObj->id) {
Abort("Bad attachment id. Couldn't find attachment '$attach'\n");
}
unless ($AttachmentObj->TransactionId() == $trans ) {
Abort("Bad transaction number for attachment. $trans should be".$AttachmentObj->TransactionId() ."\n");
}{% endhighlight %}
显然，该图片url对应的就是$trans=123456;$attach=654321。

再看RT/Attachment.pm，里面记录的是Attachments表的情况；再看其中的Create{}中相关部分如下：
{% highlight perl  %}
        my $id = $self->SUPER::Create(
            TransactionId   => $args{'TransactionId'},
            ContentType     => $Attachment->mime_type,
            ContentEncoding => $ContentEncoding,
            Parent          => $args{'Parent'},
            Headers         => $Attachment->head->as_string,
            Subject         => $Subject,
            Content         => $Body,
            Filename        => $Filename,
            MessageId       => $MessageId,
        );{% endhighlight %}
基本可以通过工单的id、url里的transactionid和Filename来唯一确定这个特大的图片了。

（实际这个Filename已经在transactionid生成的时候可以无视掉了，参见RT/Transaction_Overlay.pm里的Create{}。所以url里不管最后一段写什么*.jpg，结果都一样）
{% highlight mysql %}# mysql -uroot -p
> select * from rt3.Attachments where id='1234' and TransactionId='123456' and Filename='12.jpg';{% endhighlight %}
然后屏幕开始哗哗的刷，全是-------

因为把图片内容存在Content字段里，显示就全是-了。

不过还是担心，万一这个-不是想象中的呢？

于是去找binlog。通过strings binlog.* | awk '/12.jpg/ &amp;&amp; /'$Date'/{print NR}'找到当初create的记录（好在不是啥繁忙的系统，不然这种方法能被DBA鄙视死……），然后通过awk 'NR>a &amp;&amp; NR<b'的方式查看create记录附件的其他内容。果然在Content字段，有几百行乱码，最开头就是JFIF，也就是jpg的图片格式。

最后update rt3.Attachments set Content='' where id='1234' and TransactionId='123456' and Filename='12.jpg';删除这个超大图片，浏览页面就变快多啦~~
