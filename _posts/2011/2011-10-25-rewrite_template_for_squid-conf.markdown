---
layout: post
title: 用Template::Tookit给squid.conf写模板
date: 2011-10-25
category: perl
---

本文纯属练习Template模块使用，是否可以运用到生产，是否有必要运用到生产，都是未知数……
包括如下文件：
```bash[raocl@localhost tt2-test]$ tree
.
|-- config-cdcgame.net.yml
|-- config-china.com.yml
|-- config.tt
|-- hostconfig.yml
|-- squid.layout.tt
`-- tt4squid.pl

0 directories, 6 files```
其中tt4squid.pl如下：
```perl#!/usr/bin/perl
use warnings;
use strict;
use Template;
use YAML::Syck;

my $config_path = './';
my $data = LoadFile("${config_path}hostconfig.yml");
$data->{'configs'} = \&loadconfigs;
my $tt = Template->new;
$tt->process("$ARGV[0]", $data) or die $tt->error;

sub loadconfigs {
    my @ref_array;
    my @ymls = grep {s/${config_path}config-(.+?\.yml)/$1/} glob("${config_path}*");
    foreach my $yml (@ymls) {
        my $hash_ref = LoadFile("${config_path}config-${yml}");
        push @ref_array, $hash_ref;
    };
    return \@ref_array;
};```
config.tt模板如下：
```perl[%# 用%后面紧跟的#表示注释。用%紧跟的-表示消除外面的一个\s。 %]
[%# 用WRAPPER表示加入layout模板，这个跟INCLUDE/PROCESS有点不同，之前Dancer的时候用过 %]
[% WRAPPER squid.layout.tt -%]
[% FOREACH config IN configs %]
####[% config.custom %]
[% IF config.rewrite -%]
acl [% config.custom %]_url_rewrite url_regex -i [% config.rewrite.url_regex %]
url_rewrite_access deny ![% config.custom %]_url_rewrite
url_rewrite_program [% config.rewrite.program %]
url_rewrite_concurrency [% config.rewrite.concurrency %]
[% END -%]
[% IF config.cache_deny_list -%]
[% FOREACH list IN config.cache_deny_list -%]
acl no_cache_acl4[% config.custom %] url_regex -i [% list %]
[% END -%]
cache deny no_cache_acl4[% config.custom %]
[% END -%]
[% IF config.http_access_list -%]
[% FOREACH prior_list IN config.http_access_list -%]
[% FOREACH list IN prior_list -%]
acl acl_[% config.custom %]_[% list.access %]_[% list.priority %] url_regex -i [% list.url_regex %]
[% END -%]
[%# 这里虽然END退出了循环，但是原来内存里的数据没有清除，所以下一行的list数据结构就是上面循环的最后一次执行结果 %]
http_access [% list.access %] acl_[% config.custom %]_[% list.access %]_[% list.priority %]
[% IF list.allow_referer -%]
acl not_null_referer referer_regex -i .
acl [% config.custom %]_allow_referer referer_regex -i
[%- FOREACH referer IN list.allow_referer -%]
 [% referer -%]
[% END %]
http_access allow acl_[% config.custom %]_[% list.access %]_[% list.priority %] !not_null_referer
http_access deny acl_[% config.custom %]_[% list.access %]_[% list.priority %] [% config.custom %]_allow_referer
[% END -%]
[% IF config.deny_info -%]
deny_info [% config.deny_info %] acl_[% config.custom %]_[% list.access %]_[% list.priority %]
[% END -%]
[% END -%]
[% END -%]
[% IF config.refresh_patterns -%]
[% FOREACH pattern IN config.refresh_patterns -%]
refresh_pattern -i [% pattern.url_regex %] [% pattern.min %] [% pattern.per %]% [% pattern.max %]
[%- FOREACH option IN pattern.options -%]
 [% option -%]
[% END -%]
[% END -%]
[% END -%]
[% END %]
[% END %]```
通过WRAPPER加载的squid.layout.tt模板如下：
```squid#################ACL1############################
acl all src 0.0.0.0/0.0.0.0
#############################################
http_port [% http_port %] accel vhost vport http11 allow-direct
icp_port 0
acl shoutcast rep_header X-HTTP09-First-Line ^ICY.[0-9]
upgrade_http0.9 deny shoutcast
negative_ttl [% negative_ttl %] second
refresh_stale_hit 0 minute
vary_ignore_expire on
acl apache rep_header Server ^Apache
broken_vary_encoding allow apache
cache_vary on
cache_mgr [% admin_email %]
visible_hostname [% local_hostname %]
icp_access deny all
cache_effective_user nobody
cache_effective_group nobody
httpd_suppress_version_string on
debug_options ALL,1
#####################################
pipeline_prefetch on
pid_filename /var/run/squid.pid
hierarchy_stoplist
[%- FOREACH stop IN stoplist -%]
 [% stop -%]
[% END %]
######################################
cache_mem [% cache_mem %] MB
maximum_object_size_in_memory [% max_in_mem %] KB
maximum_object_size [% max_obj %] MB
minimum_object_size 0 KB
[% FOREACH coss IN cossdirs -%]
cache_dir coss [% coss.dir %] [% coss.dir_size %] max-size=[% coss.max_size %] block-size=[% coss.block_size %] membufs=[% coss.membufs %]
[% END -%]
[% FOREACH aufs IN aufsdirs -%]
cache_dir aufs [% aufs.dir %] [% aufs.dir_size %] [% aufs.num_1st %] [% aufs.num_2nd %] min-size=[% aufs.min_size %]
[% END -%]
quick_abort_min 32 KB
quick_abort_max 32 KB
quick_abort_pct 95
store_dir_select_algorithm round-robin
cache_replacement_policy lru
cache_swap_low [% swap_low %]
cache_swap_high [% swap_high %]
#################log#######################################
logformat apache_like %tl %6tr %>a %Ss/%03Hs %<st %rm %ru %Sh/%<A %mt "%{Referer}>h" "%{User-Agent}>h"
access_log [% access_log %] [% logformat %]
cache_log [% cache_log %]
cache_store_log none
logfile_rotate 4
strip_query_terms off
#################configs###################################
[%# 这里就是使用WARPPER特别的一点，必须用content标签标记插入位置 %]
[% content %]
http_reply_access allow all
refresh_pattern -i .tar 180 20% 10080 override-expire ignore-reload reload-into-ims
##########ACL2###################
acl Safe_ports port 80
acl manager proto cache_object
acl ControlCenter src 127.0.0.1
acl PURGE method PURGE
http_access allow Safe_ports
http_access allow PURGE ControlCenter
http_access allow manager ControlCenter
http_access deny PURGE !ControlCenter
http_access deny all
#############snmp############################
acl snmppublic snmp_community cacti_china
snmp_access allow snmppublic ControlCenter
snmp_access deny all
always_direct allow all```
最后域名配置config-china.com.yml如下：
```yaml---
#yaml格式，用"  "区分层次，用": "区分hash，用"- "区分array
cache_deny_list: 
  - "^http://www.china.com/"
  - "^http://bbs.china.com/.*.html"
custom: china
http_access_list: 
#下面两个-，第一个是优先级的数组标示，第二个是同一优先级里多条acl的数组标示
  - 
    - 
      access: deny
      priority: 9
      url_regex: "^http://www.china.com/index.html"
    - 
      access: deny
      priority: 9
      url_regex: "^http://news.china.com/.*.htm"
#嗯，上面优先级为9的数组元素里有两个acl，下面优先级为8和7的数组元素里都只有一个acl
  - 
    - 
      access: allow
      priority: 8
      url_regex: "^http://.*.china.com/.*.html"
  - 
    - 
      access: deny
      allow_referer: 
        - china.com
        - cdc.com
      deny_info: http://dvs.china.com/do_not_delete.png
      priority: 7
      url_regex: '^http://img.china.com/.*\.jpg$'
refresh_patterns: 
  - 
    max: 1440
    min: 180
    options: 
      - ignore-reload
      - reload-into-ims
    per: 20
    url_regex: '^http://.*china.com/.+\.(jsp|do)'```
另一个配置config-cdcgame.net.yml如下：
```yaml
custom: cdcgame
rewrite:
  concurrency: 5
  program: /usr/local/squid/bin/rewrite.pl
  url_regex: '^http://www.cdcgame.net/[0-9]+\.js\?'```
主要解决的就是acl和http_access的配合问题，最后想是通过优先级数组的方式，同一优先级的acl写完后就先写对应的http_access；这样yml书写起来有些啰嗦，最好还是能有web页面~~
最后运行命令"perl tt4squid.pl config.tt"，结果如下：
```squid#################ACL1############################
acl all src 0.0.0.0/0.0.0.0
#############################################
http_port 80 accel vhost vport http11 allow-direct
icp_port 0
acl shoutcast rep_header X-HTTP09-First-Line ^ICY.[0-9]
upgrade_http0.9 deny shoutcast
negative_ttl 120 second
refresh_stale_hit 0 minute
vary_ignore_expire on
acl apache rep_header Server ^Apache
broken_vary_encoding allow apache
cache_vary on
cache_mgr admin@test.com
visible_hostname bja-01.test.com
icp_access deny all
cache_effective_user nobody
cache_effective_group nobody
httpd_suppress_version_string on
debug_options ALL,1
#####################################
pipeline_prefetch on
pid_filename /var/run/squid.pid
hierarchy_stoplist aspx cgi \?
######################################
cache_mem 512 MB
maximum_object_size_in_memory 56 KB
maximum_object_size 8 MB
minimum_object_size 0 KB
cache_dir coss /coss 1000000 max-size=8000000 block-size=8000 membufs=512
cache_dir coss /coss2 1000000 max-size=8000000 block-size=8000 membufs=512
cache_dir aufs /aufs 1000000 128 128 min-size=8000000
quick_abort_min 32 KB
quick_abort_max 32 KB
quick_abort_pct 95
store_dir_select_algorithm round-robin
cache_replacement_policy lru
cache_swap_low 70
cache_swap_high 85
#################log#######################################
logformat apache_like %tl %6tr %>a %Ss/%03Hs %<st %rm %ru %Sh/%<A %mt "%{Referer}>h" "%{User-Agent}>h"
access_log /data/proclog/squid/access_log apache_like
cache_log /data/proclog/squid/cache_log
cache_store_log none
logfile_rotate 4
strip_query_terms off
#################configs###################################

####cdcgame
acl cdcgame_url_rewrite url_regex -i ^http://www.cdcgame.net/[0-9]+\.js\?
url_rewrite_access deny !cdcgame_url_rewrite
url_rewrite_program /usr/local/squid/bin/rewrite.pl
url_rewrite_concurrency 5

####china
acl no_cache_acl4china url_regex -i ^http://www.china.com/
acl no_cache_acl4china url_regex -i ^http://bbs.china.com/.*.html
cache deny no_cache_acl4china
acl acl_china_deny_9 url_regex -i ^http://www.china.com/index.html
acl acl_china_deny_9 url_regex -i ^http://news.china.com/.*.htm
http_access deny acl_china_deny_9
acl acl_china_allow_8 url_regex -i ^http://.*.china.com/.*.html
http_access allow acl_china_allow_8
acl acl_china_deny_7 url_regex -i ^http://img.china.com/.*\.jpg$
http_access deny acl_china_deny_7
acl not_null_referer referer_regex -i .
acl china_allow_referer referer_regex -i china.com cdc.com
http_access allow acl_china_deny_7 !not_null_referer
http_access deny acl_china_deny_7 china_allow_referer
refresh_pattern -i ^http://.*china.com/.+\.(jsp|do) 180 20% 1440 ignore-reload reload-into-ims

http_reply_access allow all
...(略)```
