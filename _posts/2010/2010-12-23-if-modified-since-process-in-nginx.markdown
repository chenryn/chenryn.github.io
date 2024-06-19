---
layout: post
theme:
  name: twitter
title: ims在nginx上的处理（无责任猜测）
date: 2010-12-23
category: nginx
---

最近得知CDN方面默认配置了reload-into-ims，而我们的html因为采用了ssi的include方式的原因，是没有last-modified的。在这种情况下的处理结果，让人好奇~

因为手头没测试机器，仅从我一知半解的nginx代码上推测一下：

1、之前博客里已经写过，nginx的ssi_module，在ngx_ssi_header_filter中简单的采用了ngx_http_clear_last_modified(r)抹去了last-modified的输出。

2、在nginx的module定义中，各filter的顺序如下：
<code>ngx_module_t *ngx_modules[] = {</code><code>
</code><code>...............................................
</code><code>&amp;ngx_http_write_filter_module,</code><code>
</code><code>&amp;ngx_http_header_filter_module,</code><code>
</code><code>&amp;ngx_http_chunked_filter_module,</code><code>
</code><code>&amp;ngx_http_range_header_filter_module,</code><code>
</code><code>&amp;ngx_http_gzip_filter_module,</code><code>
</code><code>&amp;ngx_http_postpone_filter_module,</code><code>
</code><code>&amp;ngx_http_ssi_filter_module,</code><code>
</code><code>&amp;ngx_http_charset_filter_module,</code><code>
</code><code>&amp;ngx_http_userid_filter_module,</code><code>
</code><code>&amp;ngx_http_headers_filter_module,</code><code>
</code><code>&amp;ngx_http_copy_filter_module,</code><code>
</code><code>&amp;ngx_http_range_body_filter_module,</code><code>
</code><code>&amp;ngx_http_not_modified_filter_module,</code><code>
</code><code>NULL</code><code>};</code>
越后面的越先处理。也就是说，一个带有ims请求，会先经过not_modified_filter，然后才是ssi_filter。
而在ssi抹掉last-modified之前，文件是应该存在last-modified的。
nginx默认情况下，对一个ims请求的处理流程，参见淘宝核心系统部雕梁童鞋的博客《<a href="http://www.pagefault.info/?p=66">nginx中处理http header详解(1)</a>》。大体上，是nginx获得这个请求文件的Mtime，存为变量last_modified_time；然后通过ngx_http_parse_time()换算IMS中的时间。如果ims!=last_modified_time，读取文件内容成response-body，否则clear掉content-length/content-type/content-encoding/accept-ranges等，进入下一步。

那么，如果一个html页本身没有修改，其中含有<!--#include virtual="/ssi/test.html"-->，而这个/ssi/test.html却变动了，那么在向这个html页发送ims的时候，就应该会是返回一个Not Modified，但在ssi_filter里又把last-modified也clear了……

3、在ssi_filter里如果要输出last-modified的话，如果单纯只是注释掉clear，并不起作用。不过在ngx_http_ssi_filter_module.c中，看到ngx_http_ssi_include()中调用了ngx_http_ssi_stub_output()这个handler，对virtual或file的拼接时处理header中的content-type如下：
if (!r->header_sent) {
r->headers_out.content_type_len =
r->parent->headers_out.content_type_len;
r->headers_out.content_type = r->parent->headers_out.content_type;
if (ngx_http_send_header(r) == NGX_ERROR) {
return NGX_ERROR;
}
}
return ngx_http_output_filter(r, out);

或许在这里加上
对r->parent->headers_out.last_modified_time和r->child->headers_out.last_modified_time的大小判断，然后赋值给r->headers_out.last_modified_time，然后把ssi_filter优先到not_modified_filter之前来？

C盲睡觉去也~~找时间写几个shtml测一下就知道自己对next_header_filter的理解对不对了~
