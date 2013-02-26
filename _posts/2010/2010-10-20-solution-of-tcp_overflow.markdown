---
layout: post
title: tcp overflow报错
date: 2010-10-20
category: linux
---

在对TCP参数进行sysctl优化时，通常会减小net.ipv4.tcp_max_tw_buckets这个设置，以减少服务器的TIME_WAIT数量，提高服务器响应速度。

不过对于squid服务器来说，这个优化没什么作用，而且在/var/log/messages和dmesg中大屏大屏的出现如下kernel报错。很是烦人……
printk: 7277 messages suppressed.
TCP: time wait bucket table overflow

更深一步，如果去linux内核代码中搜索的话，可以发现如下：

struct inet_timewait_sock *tw = NULL;
const struct inet_connection_sock *icsk = inet_csk(sk);
const struct tcp_sock *tp = tcp_sk(sk);
int recycle_ok = 0;

if (tcp_death_row.sysctl_tw_recycle &amp;&amp; tp->rx_opt.ts_recent_stamp)
recycle_ok = icsk->icsk_af_ops->remember_stamp(sk);

if (tcp_death_row.tw_count < tcp_death_row.sysctl_max_tw_buckets)
tw = inet_twsk_alloc(sk, state);

if (tw != NULL) {

......

} else {

/* Sorry, if we're out of memory, just CLOSE this
* socket up.  We've got bigger problems than
* non-graceful socket closings.
*/
LIMIT_NETDEBUG(KERN_INFO "TCP: time wait bucket table overflow\n");
}

......

struct inet_timewait_sock *inet_twsk_alloc(const struct sock *sk, const int state)
{
struct inet_timewait_sock *tw =
kmem_cache_alloc(sk->sk_prot_creator->twsk_prot->twsk_slab,
GFP_ATOMIC);
if (tw != NULL) {

......

}
return tw;
}

也就是，报出该错有两个可能性：

1、tcp_death_row.tw_count >= tcp_death_row.sysctl_max_tw_buckets

2、调用 kmem_cache_alloc 分配 tw 错误

所以，对squid服务器，可以适当放大net.ipv4.tcp_max_tw_buckets的设置~~
