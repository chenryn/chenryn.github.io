---
layout: post
theme:
  name: twitter
title: TCP Fast Open 测试(2)
category: linux
tags:
  - tcpdump
  - httping
  - systemtap
---

接上篇。

18 日提到采用 wireshark 而不是 tcpdump 来抓取数据。wireshark 会自动把一些数据解释成可读的内容，于是看到其实在每次 httping 发出请求的时候，第一个 SYN 包后面都有附加了 TCP FASTOPEN COOKIE 请求：

![](/images/uploads/foc-req.png)

于是回头重新好好读了一下 TFO 的原理，发现自己对 TFO 的理解是有问题的 - 原先我以为在 SYN 里是可以直接带上请求数据的 - 而这很容易被攻击。实际上的流程应该是：

1. 客户端发送 SYN 包，包尾加的是一个 FOC 请求，只有 4 字节。
2. 服务器端收到 FOC 请求，验证后根据来源 IP 地址生成 COOKIE(8 字节)，将这个 COOKIE 加载 SYN+ACK 包的末尾发送回去。
3. 客户端缓存住获取到的 COOKIE 可以给下一次使用。
4. 下一次请求开始，客户端发送 SYN 包，这时候包后面带上缓存的 COOKIE，然后就是要正式发送的数据。
4. 服务器端验证 COOKIE 正确，将数据交给上层应用处理得到响应结果，然后在发送 SYN+ACK 时，不再等待客户端的 ACK 确认，即开始发送响应数据。

示图如下：

![](/images/uploads/tfo.jpg)

所以可以总结两点：

1. 第一次请求是不会有时间节约的效果的，测试至少要 `httping -F -c 2`。
2. 从第二次开始节约的时间可以认为是第一个来回，httping 本身是个 HEAD 请求，可以认为是 50% 的节约。

但是用 `-c 2` 运行依然没有看到 RTT 变化。这时候用`stap 'probe kernel.function("tcp_fastopen_cookie_gen") {printf("%d\n", $foc->len)}'` 命令发现这个最重要的生成 COOKIE 的函数(net/ipv4/tcp_fastopen.c里)居然一直没有被触发！

认真阅读了一下调用这个函数的 `tcp_fastopen_check` 函数(net/ipv4/tcp_ipv4.c里)，原来前面首先有一步检查 sysctl 的逻辑：

```c
    if ((sysctl_tcp_fastopen & TFO_SERVER_ENABLE) == 0 ||
        fastopenq == NULL || fastopenq->max_qlen == 0)
        return false;
```

这个 `TFO_SERVER_ENABLE` 常量是 2。而我电脑默认的 `net.ipv4.tcp_fastopen` 值是 1。1 只开启客户端支持 TFO，所以这里要改成 2(或者 3，如果你不打算把客户端搬到别的主机上测试的话)。

重新开始 httping 测试，RTT 依然没有缩短。这时候的 stap 命令发现 `tcp_fastopen_cookie_gen` 函数虽然触发了，但是函数里真正干活的这段逻辑依然没有触发(即 `crypto_cipher_encrypt_one`)：

```c
void tcp_fastopen_cookie_gen(__be32 addr, struct tcp_fastopen_cookie *foc)
{
    __be32 peer_addr[4] = { addr, 0, 0, 0 };
    struct tcp_fastopen_context *ctx;

    rcu_read_lock();
    ctx = rcu_dereference(tcp_fastopen_ctx);
    if (ctx) {
        crypto_cipher_encrypt_one(ctx->tfm,
                      foc->val,
                      (__u8 *)peer_addr);
        foc->len = TCP_FASTOPEN_COOKIE_SIZE;
    }
    rcu_read_unlock();
}
```

我试图通过 `stap 'probe kernel.function("tcp_fastopen_cookie_gen"){printf("%s\n", $$locals$$)}'` 来查看这个 `ctx` 是什么内容。输出显示 ctx 结构里的元素值都是问号。

目前就卡在这里。

为了验证除了这步没有其他问题，我"野蛮"的通过 systemtap 修改了一下 `tcp_fastopen_cookie_gen` 里的变量。命令如下：

```
stap 'probe kernel.function("tcp_fastopen_cookie_gen") { $foc->len = 8 }'
```

赋值为 8，就是 `TCP_FASTOPEN_COOKIE_SIZE` 常量的值。

然后再运行测试，就发现 httping 的第二次运行的 RTT 时间减半了(最后那个 F 应该就是标记为 Fastopen 的意思吧)！可见目前问题就出在这里。

    $ httping -F -g http://192.168.0.100 -c 2
    PING 192.168.0.100:80 (/url):
    connected to 192.168.0.100:80 (154 bytes), seq=0 time= 45.60 ms 
    connected to 192.168.0.100:80 (154 bytes), seq=1 time= 23.43 ms  F
    --- http://192.168.0.100/url ping statistics ---
    2 connects, 2 ok, 0.00% failed, time 2069ms
    round-trip min/avg/max = 23.4/34.5/45.6 ms


**注：上面这个强制赋值 `foc->len` 没有改变其实 `foc->val` 是空的事实，所以只能是测试验证一下想法，真用的话多客户端之间会乱套的。**
