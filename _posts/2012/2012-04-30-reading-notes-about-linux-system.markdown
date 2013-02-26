---
layout: post
title: Linux系统调优读书笔记
date: 2012-04-30
category: linux
---

今天在图书馆看书，摘抄一些有意思的细节。

# Linux服务器性能调整

  Linux内存布局NUMA：    
    非一致性读取 每个节点；    
    每个节点下有 多个管理区(ZONE)内存块；    
    内存块包括：    
        ZONE_DMA 0~16MB    
        ZONE_NORMAL 16~896MB
        ZONE_HIGHMEM 896MB~结束    
    32位处理器下，用户空间3GB，内核空间1GB；    
        内核空间除去ZONE_DMA和ZONE_NORMAL后只剩下128MB用来vmalloc/kmap等操作；    
        kmap操作用来虚拟化页表数据位，可以在32位处理器下支持64GB内存。   
    NUMA结构下8节点的互连结构，只是3个相互最近的互连；    
    不同节点之间的定时器很难一致，通常选一个做唯一定时。    

  多处理SMP：    
    松耦合系统：每个处理器都有自己的总线、内存和IO系统；    
    紧耦合系统：只运行一个OS；    
      对称系统均分任务；    
      非对称系统有一个主控处理器；    
        cache是否共享？内存、总线和IO子系统肯定是共享的，cache会带来一致性问题；    
        锁竞争导致的开销，所以N个处理器不能达到N倍效率提升；    
        affinity即绑定进程到CPU，让进程跟cache更近。    
          linux里进程是高权的线程（一般说法是反过来说线程是小型的进程）    

  集群cluster：    
    高性能：分布式任务并行处理，100+节点，通称为计算机；    
    高可用：故障问题，最多16节点，通常2~4节点，通称为企业服务器。    

  系统跟踪前提：    
    容量足够；开销较小；场景可重现；尽量无其他进程干扰除非是场景本身需要。    

  strace命令场景：    
    判断IO阻塞，内存分配及其频率等。    

  OProfile：
    opcontrol命令：设置的count要足够大，否则中断本身次数会影响结果。

  内核调度器：    
    优先级0~MAX_PRIO(140)；    
    0~100为实时任务；    
    101~140为分时任务，即nice命令调整的-20~19。    

  I/O调度器：    
    deadline：    
      read_expire;    
      seek_cost=(x+stream_unit-1)/stream_unit，默认stream_unit为4字节；    
      write_starved：读优先N次后才写；    

  文件系统：    
    hdparm：MaxMultSect参数，默认16，当前都支持32位输出了。    

  网络：    
    tcp_window_scaling、tcp_sack、tcp_fsack等。    

  进程间通信：    
    ipcs -u查看状态；    
    ipcs -l查看限制。    

  数据库：    
    OLTP在线事务处理的业务类型类似小文件，一般文件块大小在2KB左右；    
    DSS决策支持系统的业务类型类似大文件，一般文件块大小在8KB以上。    

# 网站性能监测与优化

  Netflix的Jiffy是客户端收集的开源项目；    
  sqmphoniq即是服务器端分析，也要客户端js的支持；    
  Episodes同上。    

# JRuby语言实战技术

  类与超类：    
    所有类的超类都是Object；    
    所有类都是类Class的对象。

# Hadoop实战

  chukwa监控系统：    
    在HDFS和Map/Reduce的基础上，即意味着日志非tail方式，而是有collector先行合并成大文件再存储到HDFS；    
    致力于2000+节点，1TB+日志量的集群日志分析，即意味着非实时性；    
    数据结果目前还是存MySQL里再web展示，可能会转移到HBase上。    
    流程架构类似如下：    
        N个agents(每台server一个) --HTTP--> M个collectors(每百个agent一个) --sink--> HDFS --map/reduce--> MySQL <--JSP/JS--> Web(HICC)    
    整个流程跟logstash很类似，但是logstash没有固定hadoop平台，所以不用sink这步，实时性更好；而agent的input代码段就类似于执行类似map的工作，output段就是reduce结果了。

