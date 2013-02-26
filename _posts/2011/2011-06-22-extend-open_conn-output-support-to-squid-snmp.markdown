---
layout: post
title: 给squid的snmp增加open_conn输出
date: 2011-06-22
category: monitor
tags:
  - squid
  - C
  - snmp
---

做反向代理的squid集群监控，在单机维护时，squidclient mgr:server_list里的OPEN CONNS是经常看的一项数据，不过在开启snmp支持后，在mib里却没有找到相关的数据。还一度怀疑是不是cachePeerKeepAlRecv或者cachePeerKeepSent。今天想起来去src里grep了一把源码，顺利的在squid/src/neighbors.c里看到了OPEN CONNS等数据的来源，如下：
{% highlight c %}static void
dump_peers(StoreEntry * sentry, peer * peers)
{
    peer *e = NULL;
……
    for (e = peers; e; e = e->next) {
……
        storeAppendPrintf(sentry, "OPEN CONNS : %d\n", e->stats.conn_open);
……
        storeAppendPrintf(sentry, "keep-alive ratio: %d%%\n",
            percent(e->stats.n_keepalives_recv, e->stats.n_keepalives_sent));{% endhighlight %}
然后在squid/src/snmp_agent.c里看到了这些数据的snmp输出，如下：
{% highlight c %}variable_list *
snmp_meshPtblFn(variable_list * Var, snint * ErrP)
{
    variable_list *Answer = NULL;
    struct in_addr *laddr;
    int loop, index = 0;
    char *cp = NULL;
    peer *p = NULL;
    int cnt = 0;
……
    switch (Var->name[LEN_SQ_MESH + 2]) {
    case MESH_PTBL_NAME:
        cp = p->name;
        Answer = snmp_var_new(Var->name, Var->name_length);
……
    case MESH_PTBL_KEEPAL_R:
        Answer = snmp_var_new_integer(Var->name, Var->name_length,
            p->stats.n_keepalives_recv,
            SMI_COUNTER32);
        break;
    case MESH_PTBL_INDEX:
        Answer = snmp_var_new_integer(Var->name, Var->name_length,
            index,
            ASN_INTEGER);
        break;
    default:
        *ErrP = SNMP_ERR_NOSUCHNAME;
        break;
    }
    return Answer;
}{% endhighlight %}
一对比，发现确实没有stats.conn_open输出……
好在这个比较简单，稍微改一下，就能搞出来：
1、修改squid/include/cache_snmp.h如下：
{% highlight c %}enum {                          /* cachePeerTable */
……
    MESH_PTBL_CONN_OPEN,   /*新增这个*/
    MESH_PTBL_HOST,
    MESH_PTBL_END
};{% endhighlight %}
2、修改squid/src/snmp_core.c如下：
{% highlight c %}
void
snmpInit(void)
{
……
                                            snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 2, SQ_MESH, 1, 2),
/* LEN_SQ_MESH + 2, NULL, NULL, 15,这里改成16，大概在324行，通过原来的MIB知道有15的地方就两个，peer的是后一个 */
                                                LEN_SQ_MESH + 2, NULL, NULL, 16,
……
                                                snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 15),
                                                    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0),
                                                snmpAddNode(snmpCreateOid(LEN_SQ_MESH + 3, SQ_MESH, 1, 2, 16), /*新增这个16*/
                                                    LEN_SQ_MESH + 3, snmp_meshPtblFn, peer_InstIndex, 0))),{% endhighlight %}
3、修改squid/src/snmp_agent.c如下：
{% highlight c %}……
    case MESH_PTBL_INDEX:
        Answer = snmp_var_new_integer(Var->name, Var->name_length,
            index,
            ASN_INTEGER);
        break;
/*新增下面这段，case的内容在第1步cache_snmp.h里增加了；stats.conn_open由之前grep的结果得知；INTEGER是数值类型，照抄RTT的即可*/
    case MESH_PTBL_CONN_OPEN:
        Answer = snmp_var_new_integer(Var->name, Var->name_length,
            p->stats.conn_open,
            ASN_INTEGER);
        break;
 {% endhighlight %}
4、重新编译squid，然后用snmpwalk获取数据观察：
{% highlight bash %}[root@naigos myops]# snmpwalk -v 2c -c cacti_china 10.168.168.69 .1.3.6.1.4.1.3495.1.5.1.2  -Cc  | tail
SNMPv2-SMI::enterprises.3495.1.5.1.2.13.3 = Counter32: 0
SNMPv2-SMI::enterprises.3495.1.5.1.2.14.1 = INTEGER: 1
SNMPv2-SMI::enterprises.3495.1.5.1.2.14.2 = INTEGER: 2
SNMPv2-SMI::enterprises.3495.1.5.1.2.14.3 = INTEGER: 3
SNMPv2-SMI::enterprises.3495.1.5.1.2.15.1 = INTEGER: 3
SNMPv2-SMI::enterprises.3495.1.5.1.2.15.2 = INTEGER: 5
SNMPv2-SMI::enterprises.3495.1.5.1.2.15.3 = INTEGER: 6
SNMPv2-SMI::enterprises.3495.1.5.1.2.16.1 = STRING: "10.168.170.43"
SNMPv2-SMI::enterprises.3495.1.5.1.2.16.2 = STRING: "10.168.168.73"
SNMPv2-SMI::enterprises.3495.1.5.1.2.16.3 = STRING: "10.168.168.122"{% endhighlight %}
原来的SNMPv2-SMI::enterprises.3495.1.5.1.2.15.1 = STRING: "10.168.170.43"变成了SNMPv2-SMI::enterprises.3495.1.5.1.2.16.1 = STRING: "10.168.170.43"，而SNMPv2-SMI::enterprises.3495.1.5.1.2.15.1 = INTEGER: 3就是需要的open_conn数据了！
