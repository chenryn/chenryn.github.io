---
layout: post
theme:
  name: twitter
title: Kibana 认证鉴权方案
category: logstash
tags:
  - perl
  - kibana
  - elasticsearch
  - mojolicious
---

Kibana 作为一个纯 JS 项目，一直都没有提供完整的权限控制方面的功能。只是附带了一个 `nginx.conf` 做基本的 Basic Auth。社区另外有在 nodejs 上实现的方案，则使用了 CAS 方式做认证。

不过我对这两种方案都不太满意。

1. 认证方式太单一，适应性不强；
2. 权限隔离不明确，只是通过修改 `kibana-int` 成 `kiban-int-user` 来区分不同用户的 dashboard，并不能限制用户对 ES 索引的访问。

加上 nodejs 我也不熟，最终在多番考虑后，决定抽一个晚上自己写一版。

最终代码见 <https://github.com/chenryn/kibana>。

## 原理和实现

1. 全站代理和虚拟响应

   这里不单通过 config.js 限定了 kibana 默认连接的 Elasticsearch 服务器地址和端口，还拦截伪造了 `/_nodes` 请求的 JSON 响应体。伪造的响应中也只包含自己这个带认证的 web 服务器地址和端口。

   *这么做是因为我的 kibana 版本使用的 elasticjs 库比官方新增了 sniff 功能，默认会自动轮训所有 nodes 发送请求。*

2. 新增 `kibana-auth` 鉴权索引

   在通常的 `kibana-int-user` 区分 dashboard 基础上，我新增加 `kibana-auth` 索引，专门记录每个用户可以访问的 ES 集群地址和索引前缀。请求会固定代理到指定的 ES 集群上，并且确认是被允许访问的索引。

   这样，多个用户通过一个 kibana auth 服务器网址，可以访问多个不同的 ES 集群后端。而同一个 ES 集群后端的索引，也不用担心被其他人访问到。

3. [Authen::Simple](https://metacpan.org/pod/Authen::Simple) 认证框架

   这是 Perl 一个认证框架，支持十多种不同的认证方式。项目里默认采用最简单的 htpasswd 文件记录方式，实际我线上是使用了 LDAP 方式，都没问题。

## 部署

方案采用了 Mojolicious 框架开发，代码少不说，最关键的是 Mojolicious 无额外的 CPAN 模块依赖，这对于不了解 Perl 但是又有 Kibana 权限控制需求的人来说，大大减少了部署方面的麻烦。

```bash
curl -Lk http://cpanmin.us -o /usr/local/bin/cpanm
chmod +x /usr/local/bin/cpanm
cpanm Mojolicious Authen::Simple::Passwd
```

三行命令，就可以完成整个项目的安装需求了。然后运行目录下的:

    hypnotoad script/kbnauth

就可以通过 80 端口访问这个带有权限控制的 kibana 了。

__2015 年 1 月 6 日更新：__

目前已经提供了 bundle 方式。有编译环境的可以直接用

```bash
./vendor/bin/carton install --cached
./vendor/bin/carton exec local/bin/hypnotoad script/kbnauth
```

## 权限赋值

因为 `kibana-auth` 结构很简单，kibana 一般又都是内部使用，所以暂时还没做权限控制的管理页面。直接通过命令行方式即可赋权：

```bash
curl  -XPOST http://127.0.0.1:9200/kibana-auth/indices/sri -d '{
  "prefix":["logstash-sri","logstash-ops"],
  "server":"192.168.0.2:9200"
}'
```

这样，sri 用户，就只能访问 192.168.0.2 集群上的 logstash-sri 或 logstash-ops 开头的日期型索引(即后面可以-YYYY, -YYYY.MM, -YYYY.MM.dd 三种格式)了。

## 下一步

考虑到新方案下各用户都有自己的 `kibana-int-user` 索引，已经用着官方 kibana 的用户大批量的 dashboard 有迁移成本，找个时间可能做一个迁移脚本辅助这个事情。

开发完成后，得到了 [@高伟](http://weibo.com/u/1808998161) 童鞋的主动尝试和各种 bug 反馈支持，在此表示感谢~也希望我这个方案能帮到更多 kibana 用户。

**注：我的 kibana 仓库除了新增的这个 kbnauth 代理认证鉴权功能外，本身在 kibana 分析统计功能上也有一些改进，这方面已经得到多个小伙伴的试用和好评，自认在官方 Kibana v4 版本出来之前，应该会是最好用的版本。欢迎大家下载使用！**

新增功能包括：

1. 仿 stats 的百分比统计面板(利用 PercentileAggr 接口)
2. 仿 terms 的区间比面板(利用 RangeFacets 接口)
3. 给 bettermap 增强的高德地图支持(利用 leaflet provider 扩展)
4. 给 map 增强的中国地图支持(利用 jvectormap 文件)
5. 给 map 增强的 `term_stats` 数据显示(利用 TermStatsFacets 接口)
6. 给 query 增强的请求生成器(利用 getMapping/getFieldMapping 接口和 jQuery.multiSelect 扩展)
7. 仿 terms 的 statisticstrend 面板(利用 TermStatsFacets 接口)
8. 仿 histogram 增强的 multifieldhistogram 面板(可以给不同query定制不同的panel setting，比如设置某个抽样数据 * 1000 倍和另一个全量数据做对比)
9. 仿 histogram 的 valuehistogram 面板(去除了 histogram 面板的 X 轴时间类型数据限制，可以用于做数据概率分布分析)
10. 给 histogram 增强的 threshold 变色功能(利用了 `jquery.flot.threshold` 扩展)
11. 单个面板自己的刷新按钮(避免调试的时候全页面刷新的麻烦)
12. 重写 histogram 并增强了 uniq 去重统计模式(利用 CardinalityAggr 接口)
13. 给 terms 增强的自定义脚本化字段聚合功能(利用 scriptField 方法)
14. 给 filterSrv 增强的自定义脚本化过滤器功能，配合上条的点击生成(利用 scriptFilter 接口)
15. 给 table 增强的导出 CSV 功能(利用 filesaver.js)

效果截图同样在 [README](https://github.com/chenryn/kibana/blob/master/README.md) 里贴出。欢迎试用和反馈！
