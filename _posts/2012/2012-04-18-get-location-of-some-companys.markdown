---
layout: post
theme:
  name: twitter
title: 获取造价百强公司的真实位置
category: perl
---

很久没更新，没用技术，今天稍微geek一下下。给老婆搜索她行业百强公司的具体地点，看看如果换单位的话是否方便出行~代码如下：

```perl
#!/usr/bin/perl
use Data::Dumper;
use LWP::UserAgent;
use URI;
use Web::Scraper;
use JSON::XS;
# 处理中文需要指定输入输出都用utf8格式，否则会有wide character in print的warning提示 
use utf8;
binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

# 百度地图搜索的查询结果返回的是json数据，需要转换成perl的哈希格式 
sub decode_map_json {
    my $map_json = decode_json shift;
    # 如果是距离搜索，那么$map_json->{"content"}->[0]->{"lines"}->[0]->[2]是距离；$map_json->{"taxi"}->{"detail"}->[0]->{"totalPrice"}是打的费用。
    return $map_json->{"content"}->[0]->{"addr"};
};

# 用LWP发起地图查询请求 
sub get_map_json {
    my $company = $_;
    my $ua = LWP::UserAgent->new;
    my $res = $ua->get('http://map.baidu.com/?qt=s&wd='.$company);
    return $res->decoded_content if $res->is_success;
};

# 采用Web::Scraper获取网页里的XPath内容 
sub get_company {
    my $ori_uri = shift;
    # 可以在firefox里直接查看元素的XPath，在google chrome里则需要安装Xpath Helper工具。
    # 安装完成后，使用Ctrl+Shift+X快捷键呼出顶端Xpath调试框，然后按住Shift键，用鼠标左键点击网页元素，上边框里就出现元素的Xpath和content了。
    # 注意复制过来的Xpath里的@会被perl理解成是数组的标示，所以要加上逃逸符\才行。
    my $tweets = scraper {
        process "/html/body/div[\@class='index-main layout']/div[\@class='index-main layout']/div[\@class='index-content bcolor']/div[\@class='cont']/div[\@id='fontzoom']/span[\@id='BodyLabel']/div/table", "list" => scraper {
            # 第一个scraper里不能获取tbody，原因未知。所以分成两步，先获取一个到table的scraper，再获取tbody里面的TEXT。
            process "tbody tr td:nth-child(2)", 'cont[]' => 'TEXT';
        };
    };
    my $res = $tweets->scrape(URI->new($ori_uri));
    return $res->{'list'}->{'cont'};
};

my $company = get_company('http://www.ceca.org.cn/show.aspx?id=2006');
foreach(@$company){
    print $_,"\t";
    my $json = get_map_json($_);
    print decode_map_json($json),"\n";
};
```

输出结果如下：    

    单位名称	
    上海东方投资监理有限公司	中国·上海市江宁路1306弄7号富丽大厦23楼
    中冶京诚工程技术有限公司	白广路4号
    中铁工程设计咨询集团有限公司	
    中冶赛迪工程技术股份有限公司	重庆市渝中区双钢路一号
    中国电力工程顾问集团西南电力设计院	
    上海第一测量师事务所有限公司	澳门路519弄1-5号
    中竞发（北京）工程造价咨询有限公司	知春路108号豪景大厦A座13层

搜狗地图的api只是js的，不方便弄。不然直接获取从当前地点到目的地点的距离和耗时就更好了~~百度地图页面上就没看到有api提供，虽然用着，还是鄙视一下~~

