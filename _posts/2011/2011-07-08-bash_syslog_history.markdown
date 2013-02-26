---
layout: post
title: bash_syslog_history
date: 2011-07-08
category: monitor
tags:
  - bash
---

@钚钉钬影 童鞋要试验系统日志收集处理，采用rsyslog+loganalyzer做界面，因为需求有把bash_history也带上，所以采用修改bash源码的方式。最先采用了bash4.2（bash4.2已经带了这个功能，但是默认不开启，删掉哪个/**/就行了），不过因为这个bash4.+跟redhat的network-functions脚本有点小矛盾，重启的时候报个错——虽然改起来也很简单，就是加一个./的事情——不过本着尽量改动少的原则，换回bash3.1。
bash3.1里默认没有记录syslog的代码，所以从bash4.2/bashhist.c里复制有关bash_syslog_history代码段到bash3.1中——注意不是原样复制到bashhist.c，那样不顶用——需要复制到lib/readline/history.c中，如下：
{% highlight c %}
+   #include <syslog.h>
……
void
add_history (string)
     const char *string;
{
HIST_ENTRY *temp;

+if (strlen(string)<600) {
+   syslog(LOG_LOCAL5 | LOG_INFO, "%s %s %s %s",getenv("LOGNAME"),getlogin(),ttyname(0),string);
+    }
+    else {
+      char trunc[600];
+      strncpy(trunc,string,sizeof(trunc));
+      trunc[sizeof(trunc)-1]='\0';
+    syslog(LOG_LOCAL5, LOG_INFO, "%s %s %s %s(++TRUNC)",getenv("LOGNAME"),getlogin(),ttyname(0), trunc);
+    }

if (history_stifled && (history_length == history_max_entries))
{% endhighlight %}
上面的LOG_LOCAL5和LOG_INFO都是syslog.h里的定义，所以要include进来。
然后编译使用，就能记录进/var/log/messages里了。
<hr>
话说网上关于上面的说明中，大多数没有提到需要include<syslog.h>，但是make的时候居然只报LOG_INFO和LOG_LOCAL5的未定义错误，随便把这两个改成一个已经defined过的变量，比如HISTORY，编译一样成功；而且也一样记录系统日志。唯一体现不同的地方就是loganalyzer页面上看到所有的history操作都是alert级别。
之前没了解过程的时候，还采用了mysql触发器，自动修改这个报警级别，也记录一下，毕竟是自己第一次用触发器~~
{% highlight mysql %}USE Syslog;
DROP TRIGGER IF EXISTS trig_bash_prior;
DELIMITER |
CREATE TRIGGER trig_bash_prior BEFORE INSERT ON Syslog.SystemEvents
 FOR EACH ROW BEGIN
  IF NEW.SysLogTag='-bash:' && NEW.Priority='1' THEN
   SET NEW.Priority='6';
  END IF;
 END
|
{% endhighlight %}
这个库很简单，基本数据就是记在这个单表里~~
