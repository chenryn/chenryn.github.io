---
layout: post
theme:
  name: twitter
title: Myisamchk小工具使用手册(转)
date: 2010-10-27
category: database
tags:
  - MySQL
---

前不久碰上mysql的表损坏，百度到这篇文章，现在转载过来，原文出处：<a href="http://logzgh.itpub.net/post/3185/454455">http://logzgh.itpub.net/post/3185/454455</a>

Myisamchk是MyISAM表维护的一个非常实用的工具。可以使用myisamchk实用程序来获得有关数据库表的信息或检查、修复、优化他们。myisamchk适用MyISAM表(对应.MYI和.MYD文件的表)。
1.myisamchk的调用方法
myisamchk [options] tbl_name ...
其中options指定你想让myisamchk干什么。

它允许你通过使用模式“*.MYI”指定在一个目录所有的表。
shell> myisamchk *.MYI

推荐的快速检查所有MyISAM表的方式是：

shell> myisamchk --silent --fast /path/to/datadir/*/*.MYI
当你运行myisamchk时，必须确保其它程序不使用表。

当你运行myisamchk时内存分配重要.MYIsamchk使用的内存大小不能超过用-O选项指定的。对于大多数情况，使用-O sort=16M应该足够了。
另外在修复时myisamchk需要大量硬盘空间，基本上是所涉及表空间的双倍大小。

2.myisamchk的一般选项
--debug=debug_options, -# debug_options
输出调试记录文件。debug_options字符串经常是'd:t:o,filename'。

--silent，-s
沉默模式。仅当发生错误时写输出。

--wait, -w
如果表被锁定，不是提示错误终止，而是在继续前等待到表被解锁。
如果不使用--skip-external-locking，可以随时使用myisamchk来检查表。当检查表时，所有尝试更新表的客户端将等待，直到myisamchk准备好可以继续。
请注意如果用--skip-external-locking选项运行mysqld，只能用另一个myisamchk命令锁定表。

--var_name=value
可以通过--var_name=value选项设置下面的变量:
decode_bits 9
ft_max_word_len 取决于版本
ft_min_word_len 4
ft_stopword_file 内建列表
key_buffer_size 523264
myisam_block_size 1024
read_buffer_size 262136
sort_buffer_size 2097144
sort_key_blocks 16
stats_method nulls_unequal
write_buffer_size 262136
如果想要快速修复，将key_buffer_size和sort_buffer_size变量设置到大约可用内存的25%。
可以将两个变量设置为较大的值，因为一个时间只使用一个变量。
myisam_block_size是用于索引块的内存大小。
stats_method影响当给定--analyze选项时，如何为索引统计搜集处理NULL值。

3.myisamchk的检查选项
--check, -c
检查表的错误。如果你不明确指定操作类型选项，这就是默认操作。

--check-only-changed, -C
只检查上次检查后有变更的表。

--extend-check, -e
非常仔细地检查表。如果表有许多索引将会相当慢。

--fast，-F
只检查没有正确关闭的表。

--force, -f
如果myisamchk发现表内有任何错误，则自动进行修复。

--information, -i
打印所检查表的统计信息。

--medium-check, -m
比--extend-check更快速地进行检查。只能发现99.99%的错误

--update-state, -U
将信息保存在.MYI文件中，来表示表检查的时间以及是否表崩溃了。该选项用来充分利用--check-only-changed选项，
但如果mysqld服务器正使用表并且正用--skip-external-locking选项运行时不应使用该选项。

--read-only, -T
不要将表标记为已经检查。如果你使用myisamchk来检查正被其它应用程序使用而没有锁定的表很有用

4.myisamchk的修复选项
--backup, -B
将.MYD文件备份为file_name-time.BAK

--character-sets-dir=path
字符集安装目录。

--correct-checksum
纠正表的校验和信息。

--data-file-length=len, -D len
数据文件的最大长度

--extend-check，-e
进行修复，试图从数据文件恢复每一行。一般情况会发现大量的垃圾行。不要使用该选项,除非你不顾后果。

--force, -f
覆盖旧的中间文件(文件名类似tbl_name.TMD)，而不是中断

--keys-used=val, -k val
对于myisamchk，该选项值为位值，说明要更新的索引。选项值的每一个二进制位对应表的一个索引，其中第一个索引对应位0。
选项值0禁用对所有索引的更新，可以保证快速插入。通过myisamchk -r可以重新激活被禁用的索引。

--parallel-recover, -p
与-r和-n的用法相同，但使用不同的线程并行创建所有键。

--quick，-q
不修改数据文件，快速进行修复。

--recover, -r
可以修复几乎所有一切问题，除非唯一的键不唯一时(对于MyISAM表，这是非常不可能的情况)。如果你想要恢复表，
这是首先要尝试的选项。如果myisamchk报告表不能用-r恢复，则只能尝试-o。
在不太可能的情况下-r失败，数据文件保持完好）。

--safe-recover, -o
使用一个老的恢复方法读取，按顺序读取所有行，并根据找到的行更新所有索引树。这比-r慢些，
但是能处理-r不能处理的情况。该恢复方法使用的硬盘空间比-r少。一般情况，你应首先用-r维修，如果-r失败则用-o。

--sort-recover, -n
强制myisamchk通过排序来解析键值，即使临时文件将可能很大。

5.myisamchk的其他选项
myisamchk支持以下表检查和修复之外的其它操作的选项：

--analyze，-a
分析键值的分布。这通过让联结优化器更好地选择表应该以什么次序联结和应该使用哪个键来改进联结性能。
要想获取分布相关信息，使用myisamchk --description --verbose tbl_name命令或SHOW KEYS FROM tbl_name语句。

--sort-index, -S
以从高到低的顺序排序索引树块。这将优化搜寻并且将使按键值的表扫描更快。

--set-auto-increment[=value], -A[value]
强制从给定值开始的新记录使用AUTO_INCREMENT编号(或如果已经有AUTO_INCREMENT值大小的记录，应使用更高值)。
如果未指定value，新记录的AUTO_INCREMENT编号应使用当前表的最大值加上1。

--description, -d
打印出关于表的描述性信息。
例如：
[root@qa-sandbox-1 mysql]# myisamchk -d user.MYI
MyISAM file: user.MYI
Record format: Packed
Character set: latin1_swedish_ci (8)
Data records: 6 Deleted blocks: 1
Recordlength: 346

table description:
Key Start Len Index Type
1 1 180 unique char packed stripped
181 48 char stripped

6.如何修复表

检查你的表
如果你有很多时间，运行myisamchk *.MYI或myisamchk -e *.MYI。使用-s（沉默）选项禁止不必要的信息。
如果mysqld服务器处于宕机状态，应使用--update-state选项来告诉myisamchk将表标记为'检查过的'。

简单安全的修复
首先，试试myisamchk -r -q tbl_name(-r -q意味着“快速恢复模式”)
如果在修复时，你得到奇怪的错误(例如out of memory错误)，或如果myisamchk崩溃，到阶段3。

困难的修复
只有在索引文件的第一个16K块被破坏，或包含不正确的信息，或如果索引文件丢失，你才应该到这个阶段。在这种情况下，需要创建一个新的索引文件。按如下步骤操做：

1. 把数据文件移到安全的地方。
2. 使用表描述文件创建新的(空)数据文件和索引文件：
3. shell> mysql db_name
4. mysql> SET AUTOCOMMIT=1;
5. mysql> TRUNCATE TABLE tbl_name;
6. mysql> quit
如果你的MySQL版本没有TRUNCATE TABLE，则使用DELETE FROM tbl_name。
7. 将老的数据文件拷贝到新创建的数据文件之中。（不要只是将老文件移回新文件之中；你要保留一个副本以防某些东西出错。）

回到阶段2。现在myisamchk -r -q应该工作了。（这不应该是一个无限循环）。

你还可以使用REPAIR TABLE tbl_name USE_FRM，将自动执行整个程序。

非常困难的修复
只有.frm描述文件也破坏了，你才应该到达这个阶段。这应该从未发生过，因为在表被创建以后，描述文件就不再改变了。

1. 从一个备份恢复描述文件然后回到阶段3。你也可以恢复索引文件然后回到阶段2。对后者，你应该用myisamchk -r启动。
2. 如果你没有进行备份但是确切地知道表是怎样创建的，在另一个数据库中创建表的一个拷贝。删除新的数据文件，然后从其他数据库将描述文件和索引文件移到破坏的数据库中。这样提供了新的描述和索引文件，但是让.MYD数据文件独自留下来了。回到阶段2并且尝试重建索引文件。

7.清理碎片
对Innodb 表则可以通过执行以下语句来整理碎片，提高索引速度：
ALTER TABLE tbl_name ENGINE = Innodb;
这其实是一个 NULL 操作，表面上看什么也不做，实际上重新整理碎片了。

对myisam表格，为了组合碎片记录并且消除由于删除或更新记录而浪费的空间，以恢复模式运行myisamchk：

shell> myisamchk -r tbl_name

你可以用SQL的OPTIMIZE TABLE语句使用的相同方式来优化表，OPTIMIZE TABLE可以修复表并对键值进行分析，并且可以对索引树进行排序以便更快地查找键值。

8.建立表检查计划
运行一个crontab，每天定期检查所有的myisam表格。
35 0 * * 0 /path/to/myisamchk --fast --silent /path/to/datadir/*/*.MYI

9.获取表的信息

myisamchk -d tbl_name：以“描述模式”运行myisamchk，生成表的描述
myisamchk -d -v tbl_name: 为了生成更多关于myisamchk正在做什么的信息，加上-v告诉它以冗长模式运行。
myisamchk -eis tbl_name:仅显示表的最重要的信息。因为必须读取整个表，该操作很慢。
myisamchk -eiv tbl_name:这类似 -eis，只是告诉你正在做什么。

10.Myisamchk产生的信息解释

MyISAM file
ISAM(索引)文件名。

File-version
ISAM格式的版本。当前总是2。

Creation time
数据文件创建的时间。

Recover time
索引/数据文件上次被重建的时间。

Data records
在表中有多少记录。

Deleted blocks
有多少删除的块仍然保留着空间。你可以优化表以使这个空间减到最小。参见第7章：优化。

Datafile parts
对动态记录格式，这指出有多少数据块。对于一个没有碎片的优化过的表，这与Data records相同。

Deleted data
不能回收的删除数据有多少字节。你可以优化表以使这个空间减到最小。参见第7章：优化。

Datafile pointer
数据文件指针的大小，以字节计。它通常是2、3、4或5个字节。大多数表用2个字节管理，但是目前这还不能从MySQL控制。
对固定表，这是一个记录地址。对动态表，这是一个字节地址。

Keyfile pointer
索引文件指针的大小，以字节计。它通常是1、2或3个字节。大多数表用 2 个字节管理，但是它自动由MySQL计算。
它总是一个块地址。

Max datafile length
表的数据文件(.MYD文件)能够有多长，以字节计。

Max keyfile length
表的键值文件(.MYI文件)能够有多长，以字节计。

Recordlength
每个记录占多少空间，以字节计。

Record format
用于存储表行的格式。上面的例子使用Fixed length。其他可能的值是Compressed和Packed。

table description
在表中所有键值的列表。对每个键，给出一些底层的信息：
Key
该键的编号。
Start
该索引部分从记录的哪里开始。
Len
该索引部分是多长。对于紧凑的数字，这应该总是列的全长。对字符串，它可以比索引的列的全长短些，
因为你可能会索引到字符串列的前缀。
Index
unique或multip（multiple)。表明一个值是否能在该索引中存在多次。
Type
该索引部分有什么数据类型。这是一个packed、stripped或empty选项的ISAM数据类型。
Root
根索引块的地址。
Blocksize
每个索引块的大小。默认是1024，但是从源码构建MySQL时，该值可以在编译时改变。
Rec/key
这是由优化器使用的统计值。它告诉对该键的每个值有多少条记录。唯一键总是有一个1值。
在一个表被装载后(或变更很大)，可以用myisamchk -a更新。如果根本没被更新，给定一个30的默认值。
在上面例子的表中，第9个键有两个table description行。这说明它是有2个部分的多部键。

Keyblocks used
键块使用的百分比是什么。当在例子中使用的表刚刚用myisamchk重新组织时，该值非常高(很接近理论上的最大值)。

Packed
MySQL试图用一个通用后缀压缩键。这只能被用于CHAR/VARCHAR/DECIMAL列的键。对于左部分类似的长字符串，
能显著地减少使用空间。在上面的第3个例子中，第4个键是10个字符长，可以减少60%的空间。

Max levels
对于该键的B树有多深。有长键的大表有较高的值。

Records
表中有多少行。

M.recordlength
平均记录长度。对于有定长记录的表，这是准确的记录长度，因为所有记录的长度相同。

Packed
MySQL从字符串的结尾去掉空格。Packed值表明这样做达到的节约的百分比。

Recordspace used
数据文件被使用的百分比。

Empty space
数据文件未被使用的百分比。

Blocks/Record
每个记录的平均块数(即，一个碎片记录由多少个连接组成)。对固定格式表，这总是1。该值应该尽可能保持接近1.0。
如果它变得太大，你可以重新组织表。参见第7章：优化。

Recordblocks
多少块(链接)被使用。对固定格式，它与记录的个数相同。

Deleteblocks
多少块(链接)被删除。

Recorddata
在数据文件中使用了多少字节。

Deleted data
在数据文件中多少字节被删除(未使用)。

Lost space
如果一个记录被更新为更短的长度，就损失了一些空间。这是所有这样的损失之和，以字节计。

Linkdata
当使用动态表格式，记录碎片用指针连接(每个4 ～ 7字节)。 Linkdata指这样的指针使用的内存量之和。
