---
layout: post
theme:
  name: twitter
title: 系统优化——TCP参数
date: 2010-01-19
category: linux
---

tcp_syn_retries ：INTEGER
默认值是5
对于一个新建连接，内核要发送多少个 SYN 连接请求才决定放弃。不应该大于255，默认值是5，对应于180秒左右时间。(对于大负载而物理通信良好的网络而言,这个值偏高,可修改为2.这个值仅仅是针对对外的连接,对进来的连接,是由tcp_retries1决定的)

tcp_synack_retries ：INTEGER
默认值是5
对于远端的连接请求SYN，内核会发送SYN ＋ ACK数据报，以确认收到上一个 SYN连接请求包。这是所谓的三次握手(threeway handshake)机制的第二个步骤。这里决定内核在放弃连接之前所送出的 SYN+ACK数目。不应该大于255，默认值是5 ，对应于180秒左右时间。(可以根据上面的 tcp_syn_retries来决定这个值)

tcp_keepalive_time ：INTEGER
默认值是7200(2小时)
当keepalive打开的情况下，TCP发送keepalive消息的频率。(由于目前网络攻击等因素,造成了利用这个进行的攻击很频繁,曾经也有cu的朋友提到过,说如果2边建立了连接,然后不发送任何数据或者rst/fin消息,那么持续的时间是不是就是2小时,空连接攻击?tcp_keepalive_time就是预防此情形的.我个人在做nat服务的时候的修改值为 1800 秒)

tcp_keepalive_probes： INTEGER
默认值是9
TCP发送keepalive探测以确定该连接已经断开的次数。(注意:保持连接仅在SO_KEEPALIVE套接字选项被打开是才发送.次数默认不需要修改,当然根据情形也可以适当地缩短此值.设置为5比较合适)

tcp_keepalive_intvl ：INTEGER
默认值为75
探测消息发送的频率，乘以tcp_keepalive_probes就得到对于从开始探测以来没有响应的连接杀除的时间。默认值为75秒，也就是没有活动的连接将在大约11分钟以后将被丢弃。(对于普通应用来说,这个值有一些偏大,可以根据需要改小.特别是web类服务器需要改小该值,15是个比较合适的值)

tcp_retries1 ：INTEGER
默认值是3
放弃回应一个TCP连接请求前﹐需要进行多少次重试。RFC 规定最低的数值是3 ﹐这也是默认值﹐根据RTO的值大约在3秒 - 8分钟之间。(注意:这个值同时还决定进入的syn连接)
tcp_retries2 ：INTEGER
默认值为15
在丢弃激活(已建立通讯状况)的TCP连接之前﹐需要进行多少次重试。默认值为15
，根据RTO的值来决定，相当于13-30分钟(RFC1122规定，必须大于100秒).(这个值根据目前的网络设置,可以适当地改小,我的网络内修改为了5)
tcp_orphan_retries ：INTEGER
默认值是7
在近端丢弃TCP连接之前﹐要进行多少次重试。默认值是7
个﹐相当于 50秒 - 16分钟﹐视 RTO 而定。如果您的系统是负载很大的web服务器﹐那么也许需要降低该值﹐这类 sockets
可能会耗费大量的资源。另外参的考 tcp_max_orphans 。(事实上做NAT的时候,降低该值也是好处显著的,我本人的网络环境中降低该值为3)
tcp_fin_timeout ：INTEGER
默认值是 60
对于本端断开的socket连接，TCP保持在FIN-WAIT-2状态的时间。对方可能会断开连接或一直不结束连接或不可预料的进程死亡。默认值为
60 秒。过去在2.2版本的内核中是 180
秒。您可以设置该值﹐但需要注意﹐如果您的机器为负载很重的web服务器﹐您可能要冒内存被大量无效数据报填满的风险﹐FIN-WAIT-2
sockets 的危险性低于 FIN-WAIT-1 ﹐因为它们最多只吃 1.5K 的内存﹐但是它们存在时间更长。另外参考
tcp_max_orphans 。(事实上做NAT的时候,降低该值也是好处显著的,我本人的网络环境中降低该值为30)
tcp_max_tw_buckets ：INTEGER
默认值是180000
系统在同时所处理的最大 timewait sockets
数目。如果超过此数的话﹐time-wait socket 会被立即砍除并且显示警告信息。之所以要设定这个限制﹐纯粹为了抵御那些简单的
DoS
攻击﹐千万不要人为的降低这个限制﹐不过﹐如果网络条件需要比默认值更多﹐则可以提高它(或许还要增加内存)。(事实上做NAT的时候最好可以适当地增加该值)
tcp_tw_recycle ：BOOLEAN
默认值是0
打开快速
TIME-WAIT sockets 回收。除非得到技术专家的建议或要求﹐请不要随意修改这个值。(做NAT的时候，建议打开它)
tcp_tw_reuse ：BOOLEAN
默认值是0
该文件表示是否允许重新应用处于TIME-WAIT状态的socket用于新的TCP连接(这个对快速重启动某些服务,而启动后提示端口已经被使用的情形非常有帮助)
tcp_max_orphans ：INTEGER
缺省值是8192
系统所能处理不属于任何进程的TCP
sockets最大数量。假如超过这个数量﹐那么不属于任何进程的连接会被立即reset，并同时显示警告信息。之所以要设定这个限制﹐纯粹为了抵御那些简单的
DoS 攻击﹐千万不要依赖这个或是人为的降低这个限制(这个值Redhat
AS版本中设置为 32768
,但是很多防火墙修改的时候,建议该值修改为
2000 )
tcp_abort_on_overflow ：BOOLEAN
缺省值是0
当守护进程太忙而不能接受新的连接，就象对方发送reset消息，默认值是false。这意味着当溢出的原因是因为一个偶然的猝发，那么连接将恢复状态。只有在你确信守护进程真的不能完成连接请求时才打开该选项，该选项会影响客户的使用。(对待已经满载的sendmail,apache这类服务的时候,这个可以很快让客户端终止连接,可以给予服务程序处理已有连接的缓冲机会,所以很多防火墙上推荐打开它)
tcp_syncookies ：BOOLEAN
默认值是 0
只有在内核编译时选择了CONFIG_SYNCOOKIES时才会发生作用。当出现syn等候队列出现溢出时象对方发送syncookies。目的是为了防止syn
flood攻击。
注意：该选项千万不能用于那些没有收到攻击的高负载服务器，如果在日志中出现synflood消息，但是调查发现没有收到synflood攻击，而是合法用户的连接负载过高的原因，你应该调整其它参数来提高服务器性能。参考:
tcp_max_syn_backlog
tcp_synack_retries
tcp_abort_on_overflow
syncookie严重的违背TCP协议，不允许使用TCP扩展，可能对某些服务导致严重的性能影响(如SMTP转发)。(注意,该实现与BSD上面使用的tcp
proxy一样,是违反了RFC中关于tcp连接的三次握手实现的,但是对于防御syn-flood的确很有用.)
tcp_stdurg ：BOOLEAN
默认值为0
使用 TCP urg pointer 字段中的主机请求解释功能。大部份的主机都使用老旧的 BSD解释，因此如果您在 Linux
打开它﹐或会导致不能和它们正确沟通。
tcp_max_syn_backlog ：INTEGER
对于那些依然还未获得客户端确认的连接请求﹐需要保存在队列中最大数目。对于超过 128Mb 内存的系统﹐默认值是
1024 ﹐低于 128Mb 的则为 128 。如果服务器经常出现过载﹐可以尝试增加这个数字。警告﹗假如您将此值设为大于
1024 ﹐最好修改
include/net/tcp.h 里面的
TCP_SYNQ_HSIZE ﹐以保持
TCP_SYNQ_HSIZE*16
﹐并且编进核心之内。(SYN
Flood攻击利用TCP协议散布握手的缺陷，伪造虚假源IP地址发送大量TCP-SYN半打开连接到目标系统，最终导致目标系统Socket队列资源耗尽而无法接受新的连接。为了应付这种攻击，现代Unix系统中普遍采用多连接队列处理的方式来缓冲(而不是解决)这种攻击，是用一个基本队列处理正常的完全连接应用(Connect()和Accept()
)，是用另一个队列单独存放半打开连接。这种双队列处理方式和其他一些系统内核措施(例如Syn-Cookies/Caches)联合应用时，能够比较有效的缓解小规模的SYN
Flood攻击(事实证明
)
tcp_window_scaling ：INTEGER
缺省值为1
该文件表示设置tcp/ip会话的滑动窗口大小是否可变。参数值为布尔值，为1时表示可变，为0时表示不可变。tcp/ip通常使用的窗口最大可达到65535字节，对于高速网络，该值可能太小，这时候如果启用了该功能，可以使tcp/ip滑动窗口大小增大数个数量级，从而提高数据传输的能力(RFC1323)。（对普通地百M网络而言，关闭会降低开销，所以如果不是高速网络，可以考虑设置为0 ）

tcp_timestamps ：BOOLEAN
缺省值为1
Timestamps用在其它一些东西中﹐可以防范那些伪造的 sequence 号码。一条1G的宽带线路或许会重遇到带out-of-line数值的旧sequence 号码(假如它是由于上次产生的)。Timestamp 会让它知道这是个'旧封包'。(该文件表示是否启用以一种比超时重发更精确的方法（RFC1323）来启用对 RTT 的计算；为了实现更好的性能应该启用这个选项。)

tcp_sack ：BOOLEAN
缺省值为1
使用 Selective ACK﹐它可以用来查找特定的遗失的数据报---因此有助于快速恢复状态。该文件表示是否启用有选择的应答（Selective Acknowledgment），这可以通过有选择地应答乱序接收到的报文来提高性能（这样可以让发送者只发送丢失的报文段）。(对于广域网通信来说这个选项应该启用，但是这会增加对CPU 的占用。)

tcp_fack ：BOOLEAN
缺省值为1
打开FACK拥塞避免和快速重传功能。(注意，当tcp_sack 设置为0 的时候，这个值即使设置为1 也无效)

tcp_dsack ：BOOLEAN
缺省值为1
允许TCP发送"两个完全相同"的SACK。

tcp_ecn ：BOOLEAN
缺省值为0
打开TCP的直接拥塞通告功能。

tcp_reordering ：INTEGER
默认值是3
TCP流中重排序的数据报最大数量 。 (一般有看到推荐把这个数值略微调整大一些,比如5 )

tcp_retrans_collapse ：BOOLEAN
缺省值为1
对于某些有bug的打印机提供针对其bug的兼容性。(一般不需要这个支持,可以关闭它)

tcp_wmem (3个INTEGER 变量)： min, default, max
    min ：为TCP socket预留用于发送 缓冲 的内存最小值。每个tcp socket都可以在建议以后都可以使用它。默认值为4096(4K) 。
default ：为TCP socket预留用于发送缓冲的内存数量，默认情况下该值会影响其它协议使用的net.core.wmem_default值，一般要低于net.core.wmem_default 的值。默认值为16384(16K) 。
    max : 用于TCP socket发送缓冲的内存最大值。该值不会影响net.core.wmem_max，"静态"选择参数SO_SNDBUF则不受该值影响。默认值为131072(128K) 。（对于服务器而言，增加这个参数的值对于发送数据很有帮助,在我的网络环境中,修改为了51200 131072 204800）

tcp_rmem (3个INTEGER 变量)： min , default , max

    min ：为TCP socket预留用于接收缓冲 的内存数量，即使在内存出现紧张情况下tcp socket都至少会有这么多数量的内存用于接收缓冲，默认值为8K 。
    default ：为TCP socket预留用于接收缓冲的内存数量，默认情况下该值影响其它协议使用的net.core.wmem_default值。该值决定了在tcp_adv_win_scale、tcp_app_win 和tcp_app_win=0默认值情况下，TCP窗口大小为65535。默认值为87380
    max ：用于TCP socket接收缓冲的内存最大值。该值不会影响net.core.wmem_max，"静态"选择参数 SO_SNDBUF则不受该值影响。默认值为 128K 。默认值为87380*2 bytes。（可以看出，.max的设置最好是default的两倍,对于NAT来说主要该增加它,我的网络里为51200 131072 204800）

tcp_mem (3个INTEGER 变量)：low , pressure , high
    low ：当TCP使用了低于该值的内存页面数 时，TCP不会考虑释放内存。(理想情况下，这个值应与指定给 tcp_wmem 的第 2 个值相匹配 - 这第 2 个值表明，最大页面大小乘以最大并发请求数除以页大小 (131072 * 300 / 4096 )。 )
    pressure ：当TCP使用了超过该值的内存页面数量时，TCP试图稳定其内存使用，进入pressure模式，当内存消耗低于low值时则退出pressure状态。(理想情况下这个值应该是TCP 可以使用的总缓冲区大小的最大值 (204800 * 300 / 4096 )。 )
    high ：允许所有tcp sockets用于排队缓冲数据报的页面量。(如果超过这个值，TCP 连接将被拒绝，这就是为什么不要令其过于保守 (512000 * 300 / 4096 ) 的原因了。

在这种情况下，提供的价值很大，它能处理很多连接，是所预期的 2.5 倍；或者使现有连接能够传输 2.5 倍的数据。我的网络里为192000 300000 732000)一般情况下这些值是在系统启动时根据系统内存数量计算得到的。

tcp_app_win : INTEGER
默认值是31
保留max(window/2^tcp_app_win, mss)数量的窗口由于应用缓冲。当为0时表示不需要缓冲。

tcp_adv_win_scale : INTEGER
默认值为2
计算缓冲开销bytes/2^tcp_adv_win_scale(如果tcp_adv_win_scale > 0)或者bytes-bytes/2^(-tcp_adv_win_scale)(如果tcp_adv_win_scale <= 0）。

tcp_rfc1337 :BOOLEAN
缺省值为0
这个开关可以启动对于在RFC1337中描述的"tcp的time-wait暗杀危机"问题的修复。启用后，内核将丢弃那些发往time-wait状态TCP套接字的RST包.

tcp_low_latency: BOOLEAN
缺省值为0
允许 TCP/IP 栈适应在高吞吐量情况下低延时的情况；这个选项一般情形是的禁用。(但在构建Beowulf集群的时候,打开它很有帮助)

tcp_westwood :BOOLEAN
缺省值为0
启用发送者端的拥塞控制算法，它可以维护对吞吐量的评估，并试图对带宽的整体利用情况进行优化；对于 WAN通信来说应该启用这个选项。

tcp_bic :BOOLEAN
缺省值为0
为快速长距离网络启用 Binary Increase Congestion；这样可以更好地利用以 GB 速度进行操作的链接；对于WAN 通信应该启用这个选项。

