---
layout: post
theme:
  name: twitter
title: 【翻译】用 kibana 4 调查你邻居可能投票给的人
category: logstash
tags:
  - kibana
  - elasticsearch
---

原文地址：<http://www.elasticsearch.org/blog/kibana-4-for-investigating-pacs-super-pacs-and-your-neighbors/>

是时候当一个公众黑客了！我们看到地区和联邦政府每天都公开越来越多的数据以提高行政透明度，包括交通事故，药物不良反应，高校助学金申请，餐厅检查甚至厕所位置都有。现在，所有人都能访问这个数据，分析它，然后构建应用以促进公众利益。公众黑客太棒了！

联邦选举委员会发布了竞选献金数据到它的网站(www.fec.gov)上，包括总统、参议院和众议院的。如同 fec.gov 上所说：

    “In 1975, Congress created the Federal Election Commission (FEC) to administer and enforce the Federal Election Campaign Act (FECA) – the statute that governs the financing of federal elections. The duties of the FEC, which is an independent regulatory agency, are to disclose campaign finance information, to enforce the provisions of the law such as the limits and prohibitions on contributions, and to oversee the public funding of Presidential elections.”

向公众提供这些信息是对确保选举过程的完整性是至关重要的。

所以，现在 FEC 提供给了我们原始数据，我们能做什么呢？如果你不认为自己是一个会用 R 分析数据的数据科学家，或者会做漂亮的 D3.js 可视化效果的纽约时报员工，你可能这下就卡住了。不要紧，ELK stack 可以不用多少编程，做到丰富的、可视的，交互式数据分析。数据导入的步骤我会稍后讲，现在，先让我们看看 Kibana 4 能做到些什么。

## discover

Kibana 4 里，你应该从 Discover 标签页开始。这是你得到数据集高阶感观的地方。可以查看实时的数据分布，结构化了的字段列表，一起索引中一些文档的实际内容。

![](http://www.elasticsearch.org/content/uploads/2015/02/01_discover-1024x640.png)

在上面截图里，我们看到 2013-2014 选举周期里，一共有将近 210 万条个人捐献记录。我们能看到很清晰的捐献记录增加的趋势，以及一些看起来是随机的峰值点。

左侧栏列出了数据集中所有的字段。这提供给我们可以提问的内容。比如，我们现在知道数据里有像姓名、城市、州、捐献数量和捐献日期这些字段，我们就可以构思下面这些问题了：

* 哪个州的捐献数量最大？
* 哪个州的捐献金额最大？
* 爱荷华州的个人捐献金额实时变化情况如何？
* 竞选献金数前 10 名的州里，排名前 3 的城市都是哪些？
* 我喜欢的明星(比如：格温妮丝·帕特洛)给谁捐款了么？

字段列表还能帮助你排除掉一些没法回答的问题。比如，这个记录个人捐献的文件并不包含有关委员会和相关候选人的信息(技术上说，个人捐献的去向是跟候选人相关的)。原始数据里只是记录了委员会和候选人的加密 ID。

![](http://www.elasticsearch.org/content/uploads/2015/02/02_committeeID-210x300.png)

这样，要问“接收献金最多的 10 个委员会的名字是？”就比较难了。通过 Discover 界面发现这点，有助于引导我们加载额外的数据，丰富这个应用，让它更加有用。

## visualize

当我们确定了可能要问的一些问题后，我们就可以开始基于数据集的这些属性构建可视化了。以前面说到的一个问题为例。

这是个人献金总额最多的 10 个州的饼图：

![](http://www.elasticsearch.org/content/uploads/2015/02/03_piechart1-1024x640.png)

看起来没有太多的惊喜，如饼图所示，加利福尼亚，纽约，德克萨斯，佛罗里达，伊利诺斯(美国最大的五个州)贡献了最多的捐赠。华盛顿位列第三是一个有趣的值得调研的问题 - 华盛顿作为州的话应该是倒数第三小的，或许作为联邦政府所在地，更容易引导当地居民参与政治。

饼图很好创建：

1. 选择用来确定饼图分片大小的聚合(Aggregation)种类：计数(Count)、总和(Sum)还是去重数(Unique Count)。如果你选择了总和或者去重数，Kibana 还需要知道用哪个字段的值来做这个运算。
2. 选择切片(Split Slices)来切割饼图成片。
3. 选择绘制分片的方式：
   a. Aggregation: 选择 “Terms” 因为我们是要基于字段的值来创建分片("terms" 是 Elasticsearch 里的说法)。
   b. Field: 选择要做运算的字段。本例中，我们要按照州来计算献金分布，所以选择 "state"。
   c. Order/Size: 选择 “Top” 排序，选择长度为 “10” ，这样就能创建一个前 10 名的饼图。
   d. Order by: 本例中你应该是用我们第一步里选过的函数来做排序，不过有些高级场景里你也可以在这里选择其他选项。
4. 点击 Apply 然后你就有一个漂亮的饼图了。
5. 点击右上角的 Save 图标，然后取个名字，这你可以把它添加到 Dashboard 里。

![](http://www.elasticsearch.org/content/uploads/2015/02/04_saveviz-300x239.png)

如果你在数据可视化方面有过一些经验，你可能会想“这家话真是个纯码农。饼图在这种数据分析里就是一个错误的可视化方式。”嗯，你是对的(好吧，希望不包括纯码农部分)。这里使用饼图确实给观众带来一些失真的感观，好像这里面已经包括全部 100% 的数据，就好像加利福尼亚的现金占到全国的四分之一一样。

你可以修改 "size" 参数为 "51"，这样分片数就等于实际的总数。不过如下所示，饼图看起来就不怎么漂亮了：

![](http://www.elasticsearch.org/content/uploads/2015/02/05_piechart51-1024x640.png)

更好的办法是用另一种可视化方式，比如垂直柱状图(Vertical Bar Chart)。

![](http://www.elasticsearch.org/content/uploads/2015/02/06_barchart-1024x640.png)

创建垂直柱状图的参数看起来很眼熟。因为这些跟前面创建饼图用过的一模一样，毕竟驱动可视化的背后，实际的请求就是一模一样的。我们只是用一种更不容易被误解的方式来展示而已。

## dashboard

创建可视化是蛮有趣的，不过有时候，你更希望把这些合起来放进一个漂亮的仪表板上，在这上面，执行一些聚合分析，通过多维度的字段数据获取有用的结论，然后和别人分享你的发现。

添加可视化到仪表板的时间过程非常直接。你创建好一系列可视化后，在 Dashboard 标签页的右上角点击 Add Visualizatioin 图表，然后开始添加即可！

![](http://www.elasticsearch.org/content/uploads/2015/02/07_addviztodashboard-1024x444.png)

小贴士：在你去创建可视化和仪表板之前，最好先约定保存这些元素时采用什么命名规则。比如，统一加上你的 Elasticsearch 索引名或者类型名作为前缀。

然后，你就会有一个像这样的仪表板了：

![](http://www.elasticsearch.org/content/uploads/2015/02/08_big_dashboard_ss_final-748x1024.jpg)

## 探索

让我们再看两个潜在的数据场景：一个关注特定的 Super PAC，另一个关注你加血的竞选献金。

### 这些 pac 后面都有谁?


政治行动委员会(Political Action Committees), 或者说 PAC，不是什么新东西了。第一个 PAC 在 1947 年《塔夫脱-哈特利法案》禁止工会和企业花钱影响联邦选举的时候就成立的。

Super PACs 应该是由 2010 年的两个最高法院判决促生的。判决裁定没有捐钱给具体候选人，政党或其他 PAC 的 PAC 组织，可以接收来自个人，公会和企业(包括盈利和非盈利的)的无限额捐款以保证独立的支出。[<http://en.wikipedia.org/wiki/Political_action_committee>]

Super PACs 是很多争议和辩论的来源，因为在此之前，竞选献金有很明确的额度限制。

![](http://www.elasticsearch.org/content/uploads/2015/02/09_pac01-1024x464.png)

在上面截图里，我们看到了一个有关捐献的高层次的师徒。特别是，接收捐献的顶级委员会，委员会类型(比如：Super PAC， PAC，党派等)以及利益集团的类别(比如：公司，公会等)。我可以大概猜出来很多委员会的含义，不过还是有些不太明显 —— 比如 “ACTBLUE” 和 “NEXTGEN CLIMATE ACTION COMMITTEE”。超过 七千七百万美元的献金捐给一个命名模糊不清的委员会，真的是一个值得研究的问题。

你可以在数据表格上点击元素，就能过滤这个数据集了：

![](http://www.elasticsearch.org/content/uploads/2015/02/10_pacnextgenclimate-300x247.png)

点击 “NEXTGEN CLIMATE ACTION COMMITTEE” 后，Kibana 会刷新所有其他图标，只显示捐献给这个委员会的相关数据。我们立刻就发现了一些有趣的现象：

![](http://www.elasticsearch.org/content/uploads/2015/02/11_nextgenclimate_deets-1024x376.png)

绝大多数捐献给 “NEXTGEN CLIMATE ACTION COMMITTEE” 的人是：

* 自称职位是“创始人”
* 雇主为 Fahr, LLC
* 居住在旧金山

你再点击 “FAHR, LLC” 继续钻取，很明显这些献金是来自同一个人：

![](http://www.elasticsearch.org/content/uploads/2015/02/12_nextgenclimate_deets2-1024x358.png)

在通过雇主下钻之前，我们注意到只有 56 笔献金给 “NEXTGEN CLIMATE ACTION COMMITTEE”。几次点击后，我们发现这个 Super PAC 基本都是从 1 个人以及其他极少数人那获取的资金，我们猜测这群人可能是朋友，同事或者其他关系。

而另一个大型 PAC, “ACTBLUE”，就完全不一样了。

![](http://www.elasticsearch.org/content/uploads/2015/02/13_actblue-1024x459.png)

给这个 PAC 的捐献非常多(跟上个比是 154448 vs 56)，而且捐献来源广泛分布在各个地域：

![](http://www.elasticsearch.org/content/uploads/2015/02/14_actblue-geodist-1024x360.png)

Elasticsearch 提供的一个更有趣的分析函数是关键词聚合(significant terms aggregation)。你可以在比如欺诈检测、异常检测、推荐等各方面使用关键词。Elasticsearch 官博上有一篇文章介绍这个：[Significant Terms Aggregation](http://www.elasticsearch.org/blog/significant-terms-aggregation/).

对于竞选献金数据集，使用关键词的一个例子就是识别一个特定的查询的统计特征。比如说，在很多 PAC 里，捐献者的职业是律师、退休、法官。所以，对任一 PAC 做职业排行统计，都发现不了什么有价值的信息。而使用关键词聚合，正如在表格中做的，可以看到对于 ActBlue，职位更普遍的应该是教授、自由职业和作家。

![](http://www.elasticsearch.org/content/uploads/2015/02/15_actblue-occupations-1024x357.png)

我们可以过滤另一个 PAC，民主党全国委员会(Democratic National Committee)，会发现这个 PAC 的职位都很常见了：

![](http://www.elasticsearch.org/content/uploads/2015/02/16_dnc-occupations-1024x617.png)

虽然我们开始的这次探索没有回答出关于这些 PAC 的所有问题，它触发了我希望跟踪的更多问题：

* 谁是 Thomas Steyer ，他跟他的 Super PAC 的另外大概 40 到 50 个捐献者之间是什么关系？
* NextGen Climate 和 ActBlue 支持哪个候选人？
* 这两个组织之间有什么关联？
* 有没有什么有意无意的帮助特定 PAC 的营销手段，让特定行业的雇员更有兴趣？

整个钻取过程的优点是：在帮助回答一些问题的时候，用 ELK stack 还能帮你制定出一些甚至你自己都没想到能问出来的问题!

## 我家乡的人把钱给谁了？

警告：根据你家乡的大小，你可能会发现一些让你邻居很尴尬的事情:)

所有超过 $200 的献金都被要求依法公开，所以，虽然在这里看到你邻居的信息可能比较尴尬，不过竞选县级是公众信息，公众是有这个合法知情权的。

你可以很快的钻取数据集到州、市，然后看到你家乡谁捐献了，捐给了谁。

![](http://www.elasticsearch.org/content/uploads/2015/02/17_hoboken-dashboard-1024x640.png)

新泽西的霍博肯只有 449 条记录，逐一翻阅记录也花不了多少时间。但是，如果你要分析的是纽约市的 70850 条记录，通过 ELK stack 提供的交互式用户体现就体现出明显优势了：

![](http://www.elasticsearch.org/content/uploads/2015/02/18_nyc-dashboard-1024x640.png)

回到我的家乡，新泽西的霍博肯，通过几次点击，你就可以构建出为当地参议院和众议院竞选捐献的排行榜。我一直不太明白为什么人们要出钱给 Cory Booker(赢得 56% 选票)和 Albio Sires(赢得 77.3% 选票)参与的非竞争性的比赛。或者只是因为需要支持一下朋友？不过一个关心政治的人，可能就会留意这里面的每一个细节了。

## 总结

我们刚看过了用 ELKstack 探索 FEC 竞选献金数据能做到什么。希望这也能帮你扩展使用 ELKstack 的思路，应用这些数据发现的规则到其他类型的数据是，不管是结构化的比如事务数据，非结构化的比如纯文本数据，抑或二者的混合体。

个人、非营利组织、政府机构和私人公司，从初创公司到大型企业，都在使用 ELK stack 处理实时数据集，大小从几 MB 到几 PB，随着 Kibana 4 的发布，处理会变得更容易和更强大。

## 附录 a. 如何在笔记本电脑上运行 elk 分析本数据集

如果你还没有最新版的 ELK stack 的话，可以从 <http://www.elasticsearch.org/overview/elkdownloads/> 页面上下载并依照该页说明进行安装。

实际上你并不一定需要 Logstash 来完成这件事情，不过你如果想调试一把 Logstash 配置然后自己加载原始数据，安装 Logstash 还是完全值得的。

### 恢复 elasticsearch 索引镜像

下载安装完 ELK stack 后，你需要下载献金数据的索引镜像文件(注意：这是一个 1.4GB 大的文件，小心你的手机流量):

<http://download.elasticsearch.org/demos/usfec/snapshot_demo_usfec.tar.gz>

在你本地磁盘上创建一个叫 snapshots 的文件夹，然后解压下载的 .tar.gz 文件进去。比如：

    mkdir -p ~/elk/snapshots
    cp ~/Downloads/snapshot_demo_usfec.tar.gz ~/elk/snapshots
    cd ~/elk/snapshots
    tar xf snapshot_demo_usfec.tar.gz

等你把 Elasticsearch 跑起来以后，恢复索引就只需要两步了：

1) 为镜像注册一个文件系统仓库(修改下例中 "location" 的值到你实际的 usfec 镜像目录):

    curl -XPUT 'http://localhost:9200/_snapshot/usfec' -d '{
        "type": "fs",
        "settings": {
            "location": "/tmp/snapshots/usfec",
            "compress": true,
            "max_snapshot_bytes_per_sec": "1000mb",
            "max_restore_bytes_per_sec": "1000mb"
        }
    }'

2) 调用恢复接口(Restore API endpoint)开始恢复索引数据到你的 Elasticsearch 实例:

    curl -XPOST "localhost:9200/_snapshot/usfec/1/_restore"

现在，去[喝个咖啡](https://bluebottlecoffee.com/preparation-guides)。等一会儿后，你可以调用 cat recovery API 来检查一下恢复操作是否完成：

    curl -XGET 'localhost:9200/_cat/recovery?v'

或者获取索引的文档数：

    curl -XGET localhost:9200/usfec*/_count -d '{
            "query": {
                    "match_all": {}
            }
    }'

如果全部完成的话，这个数应该是 4250251。

### 指向 kibana 4 到一个 elasticsearch 索引

你通过 localhost:5601 第一次访问 Kibana 的时候，它会要求你定义一个 “index pattern”:

![](http://www.elasticsearch.org/content/uploads/2010/02/19_indexpattern01-1024x398.png)

因为 Elasticsearch 集群可能有多个索引，你需要告诉 Kibana 哪些索引里有你希望读取的数据。在本例中，献金镜像包括了四个索引，当你运行索引恢复操作后，应该在你的 Elasticsearch 实例里创建好了四个新索引：

* usfec_indiv_contrib: 由个人捐赠给委员会
* usfec_comm2cand_contrib: 由委员会捐赠给候选人
* usfec_comm2comm_contrib: 由委员会转给其他委员会
* usfec_oppexp: 委员会运营支出

你可以输入一个索引名字到输入框，然后选择一个时间字段(我们索引里，应该是 `@timestamp`)，然后点击 Create：

![](http://www.elasticsearch.org/content/uploads/2010/02/20_indexpattern02-1024x487.png)

这篇博文的示例中，我们只用到了个人献金的数据，其他三个索引里其实还有很多价值。甚至你可以在 Kibana 里同时指向这四个索引，然后找出不同数据集之间的联系！

打开 Discover 标签，选择一个合适的时间段(选择 "From" 时间为 2012-12-18)，开始探索吧！

![](http://www.elasticsearch.org/content/uploads/2015/02/21_pickdatetimeframe-1024x640.png)

### 附录 b. 参考链接

fec.gov 的原始数据和数据字典文件
<http://www.fec.gov/finance/disclosure/ftpdet.shtml#a2013_2014>

OpenSecrets.org 资源中心: 
分析献金数据的各种资源。感谢这里提供了 FEC 数据更详细的字典。
<https://www.opensecrets.org/resources/create/>

存放文件的 Github 仓库: 
Logstash 配置, 索引模板, 解析数据创建 JSON 的 Python 脚本等
<https://github.com/elasticsearch/demo/tree/master/usfec>

