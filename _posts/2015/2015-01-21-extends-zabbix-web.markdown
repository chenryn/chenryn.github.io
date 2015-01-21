---
layout: post
title: 扩展 Zabbix Web 页面功能
category: monitor
tags:
  - zabbix
  - php
---

zabbix 是目前非常流行的一个开源监控系统。虽然核心代码是 C 的，却通过 PHP 的 web 端提供了非常方便的界面和 RPC 接口。可以看到很多讲如何通过 RPC 接口自动化 zabbix 操作的文章。不过，如果你想做的事情正好没有现成的接口或者界面，怎么办呢？这时候就感谢 zabbix 的后端是用的 MySQL 数据库了，这意味着我们可以很方便的扩展 Zabbix 页面和接口的功能。

打个比方：**我们一般都会按照 hostgroup 给某个 item 做一个 summary 汇总，然后针对 summary 的值来做报警。但是收到报警的时候，怎么能快速的知道这个 group 里是哪些 host 情况相对更严重呢？**

zabbix 页面和接口，都没有提供这种信息查看方式。所以，我们需要自动动手，实现这个功能。

[@南非蜘蛛](http://weibo.com/spider4k) 的 [zatree 项目](https://github.com/spider4k/zatree)，解决了跟这个类似的问题。它的着手点是：针对 hostgroup 查看 graph，通过 graph 完成肉眼查看对比和 item 值的排序。但是，单个 graph 上可能就需要加载很多 item 信息。在 hostgroup 较大，或者单 host 监控项较多的情况下，zatree 直接就因为获取过多信息得不到 MySQL 响应变得无法正常访问了。

我的思路是：

1. 获取 hostgroup 列表供选择；
2. 根据选择的 hostgroup 获取 item 列表；
3. 根据选择的 hostgroup 和 item 获取全部 host 的 lastvalue 并排序；
4. 排序后的 host 应该提供 history 的 graph 查看链接；
5. 尽可能借用 zabbix-web 的界面。

这其中的第 1、3 步都是有现成的 API 的，直接用 hostgroup.get 和 item.get 即可。主要说说第 2、5 步。

## 新增 API

前面说了，API 扩展其实就是通过 MySQL 操作完成。这里通过已知 groupid 获取 item 列表，放到 MySQL 里其实就是一行 select 语句：`SELECT DISTINCT key_ FROM items WHERE hostid IN (SELECT hostid FROM hosts_groups WHERE groupid='1');`。

而要实现在界面上，最简单的方式，参考 `include/items.inc.php` 里的 *get_item_by_hostid* 方法，可以定义函数如下：

{% highlight php %}
function get_items_by_groupid($groupid) {
        $items = array();
        $sql = 'SELECT DISTINCT key_ FROM items WHERE hostid IN (' .
                       'SELECT hostid FROM hosts_groups WHERE groupid=' . zbx_dbstr($groupid) .
                       ')';
        $db_items = DBselect($sql);
        while ($item = DBfetch($db_items)) {
                array_push($items, $item['key_']);
        }
        return $items;
}
{% endhighlight %}

这就可用了。

不过这个函数你只能在 require 了 items.inc.php 的 PHP 页面里使用，不能暴露成 RPC 接口。

### 修改为 RPC 接口

首先要简介一下 zabbix 的 RPC 接口是怎么传递的：

    api_jsonrpc.php
    |-> api/rpc/class.cjsonrpc.php
        |-> api/rpc/class.czbxrpc.php
            |-> include/classes/api/API.php

在 API.php 中，通过 `getObjectClassName` 方法，在本文件里的 `$classMap` 获取对象的类名。

所以，添加一个接口，分为几步：

1. 实现新的类；
2. 在 API.php 的 `$classMap` 里添加对应键值对；
3. 在 API.php 中添加返回对应类的方法(这步是为了能在其他代码里用 `API::Item()` 这样的调用方式)。

好，第一步，创建 `api/classes/CItemByGroup.php` 文件，内容如下：

{% highlight php %}
<?php
class CItemByGroup extends CZBXAPI {
        public function get($groupid) {
                $items = array();
                $sql = 'SELECT DISTINCT key_ FROM items WHERE hostid IN (' .
                               'SELECT hostid FROM hosts_groups WHERE groupid=' . zbx_dbstr($groupid) .
                               ')';
                $db_items = DBselect($sql);
                while ($item = DBfetch($db_items)) {
                        array_push($items, $item['key_']);
                }
                return $items;
        }
}
{% endhighlight %}

第二步，添加 `$classMap` 键值对，内容如下：

{% highlight php %}
    'itembygroup' => 'CItemByGroup',
{% endhighlight %}

第三步，添加对应方法，内容如下：

{% highlight php %}
        /**
         * @return CItemByGroup
         */
        public static function ItemByGroup() {
                return self::getObject('itembygroup');
        }
{% endhighlight %}

这样，之前页面中直接使用 `get_items_by_groupid($groupid)` 的代码，就可以改写成：

{% highlight php %}
$items = API::ItemByGroup()->get($groupid);
{% endhighlight %}

而在其他程序里，则可以用过 **itembygroup.get** 这个 RPC 接口获取相同结果了。

## Zabbix Web 的布局和各种 helper 函数

zatree 项目中完全自己写了整个页面，所以像授权啊、返回其他页啊都比较麻烦。所以我们尽量了解一下 zabbix web 本身是怎么写的页面，把数据融合到整体风格里面去。

其实 zabbix web 页面布局非常简单。主要分为三部分：

1. include/page_header.php
2. new CWidget
3. include/page_footer.php

header 和 footer 是很顾名思义的。不过 `page_header.php` 里，通过 `include/menu.inc.php` 的 `zbx_construct_menu()` 方法，会校验访问者的权限。

### 新增页面授权

`menu.inc.php` 也很简单，跟前面 api 类似，也是一个大变量来控制菜单和页面的权限，这个变量叫 `$ZBX_MENU`。`$ZBX_MENU` 数组存放的，就是 zabbix web 顶部菜单大家看到的那几个标签，Monitoring、Report 等等。如果打算把页面加在顶部菜单上，那么就直接添加一个元素到 `$ZBX_MENU` 数组，如下：

{% highlight php %}
        'sort' => array(
                'label'                 => _('Sort'),
                'user_type'             => USER_TYPE_ZABBIX_USER,
                'default_page_id'       => 0,
                'force_disable_all_nodes'=> true,
                'pages' => array(
                        array(
                                'url' => 'sort.php','label' => _('Sort')
                        )
                )
         ),
{% endhighlight %}

如果打算加到到次级菜单，比如放到 Monitoring 下面，那么找到 `view` 元素(其 label 为 "Monitoring")，在其 `pages` 数组里加上即可：

{% highlight php %}
                'pages' => array(
			...
                        array(
                                'url' => 'sort.php',
                                'label' => _('Sort'),
                        )
                )
        ),
{% endhighlight %}

### CWidget 及其他组件

zabbix 虽然没有使用特别明确的 MVC 框架，倒也不用大家到处自己去拼接输出 HTML 代码，它已经实现了很多 helper 函数。

比如：

* group 和 item 的选择器，可以用 `CComboBox()` 生成；
* 页面交互的表单，可以用 `CForm()` 生成；
* 数据展示的表格，可以用 `CTableInfo()` 生成；
* history graph 的链接，可以用 `CLink()` 生成；

然后，`CTableInfo()` 可以 `->addRow()`；`CForm()`、 `CComboBox()` 和 `CWidget()` 都可以 `->addItem()`。

把各种元素都添加到 CWidget 里以后，调用 `->show()` 方法即可。

此外，还提供有 `check_fields`, `get_request`, `validate_sort_and_sortorder`, `getPageSortOrder`, `make_sorting_header` 和 `order_result` 等方法帮助处理请求参数和数据表格展示。

最后效果如下：

![](/images/uploads/zabbix_sort_web.jpg)

