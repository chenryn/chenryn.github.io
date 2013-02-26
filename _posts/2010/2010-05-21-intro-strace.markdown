---
layout: post
title: strace进程跟踪排错一例
date: 2010-05-21
category: linux
tags:
  - strace
---

在对HTTPS进行反向代理的时候，如果源站未能提供SSL的cert和key，可以采用TCP协议的端口转发完成。最常见的是iptables，还有rinetd。之前的博文中都有提到。    
今天碰到一个事情，使用rinetd进行443转发的客户，全网都无法访问了……    
proxy上对源站443端口能telnet通，绑定ie访问源站是没有问题；proxy的443端口本地也能telnet通，但是ie访问就是打不开任何页面。    
偶然想起strace，觉得对rinetd进程进行跟踪试试。strace -p 13916，然后这边打开ie，输入https的域名，回车……    
看到服务器tty上显示如下信息：    
select(16, [4], [], NULL, NULL)         = 1 (in [4])    
#rinetd程序处于select()，运行的FD为4    
accept(4, {sa_family=AF_INET, sin_port=htons(3766), sin_addr=inet_addr("211.99.216.18")}, [16]) = 6    
#从我本机的3766端口发起请求，被服务器接受，FD为6    
ioctl(6, FIONBIO, [1])                  = 0    
#设定该socket为阻塞状态    
setsockopt(6, SOL_SOCKET, SO_LINGER, [0], 4) = -1 EINVAL (Invalid argument)    
#设定其为异步处理方式，不错失败了……汗    
socket(PF_INET, SOCK_STREAM, IPPROTO_TCP) = 7    
#打开FD为7的socket，tcp传输方式为stream流方式    
bind(7, {sa_family=AF_INET, sin_port=htons(0), sin_addr=inet_addr("0.0.0.0")}, 16) = 0    
#服务器打开对任一端口的监听    
setsockopt(7, SOL_SOCKET, SO_LINGER, [0], 4) = -1 EINVAL (Invalid argument)    
ioctl(7, FIONBIO, [1])                  = 0    
#设定这个向源请求的socket为已阻塞    
connect(7, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("222.73.34.25")}, 16) = -1 EINPROGRESS (Operation now in progress)    
#向222.73.34.25的443端口发送请求    
select(16, [4 6 7], [], NULL, NULL)     = 1 (in [6])    
recvfrom(6, "2631A1=31K36536423"217:352346225207N7qP'342!2008"..., 1024, 0, NULL, NULL) = 70    
#从FD6即连接客户电脑的socket收到的内容    
select(16, [4 6 7], [7], NULL, NULL)    = 2 (in [7], out [7])    
recvfrom(7, 0x111e6860, 1024, 0, 0, 0)  = -1 EHOSTUNREACH (No route to host)    
#从FD7即回源的socket收到的内容——“无法找到连接主机的路由”！！    
close(7)                                = 0    
#关闭FD7    
select(16, [4 6], [6], NULL, NULL)      = 1 (out [6])    
time(NULL)                              = 1274410006    
stat("/etc/localtime", {st_mode=S_IFREG|0644, st_size=405, ...}) = 0    
close(6)                                = 0    
#关闭FD6，这个是我关闭ie后关闭的。    
很奇怪呀，这个222.73.34.25是什么地址？ping客户域名返回的明明不是这个ip呀？    
试着kill rinetd，然后重启动rinetd服务。再重复如上操作。相关内容如下：    
accept(4, {sa_family=AF_INET, sin_port=htons(3917), sin_addr=inet_addr("211.99.216.18")}, [16]) = 6    
ioctl(6, FIONBIO, [1])                  = 0    
setsockopt(6, SOL_SOCKET, SO_LINGER, [0], 4) = -1 EINVAL (Invalid argument)    
socket(PF_INET, SOCK_STREAM, IPPROTO_TCP) = 7    
bind(7, {sa_family=AF_INET, sin_port=htons(0), sin_addr=inet_addr("0.0.0.0")}, 16) = 0    
setsockopt(7, SOL_SOCKET, SO_LINGER, [0], 4) = -1 EINVAL (Invalid argument)    
ioctl(7, FIONBIO, [1])                  = 0    
connect(7, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("219.235.4.17")}, 16) = -1 EINPROGRESS (Operation now in progress)    
#回源地址是219.235.4.17，这个正是ping出来的正确源ip！    
select(18, [4 6 7], [], NULL, NULL)     = 1 (in [6])    
recvfrom(6, "2631A1=31K365365f334370210367202260B33332E3337232423340s21"..., 1024, 0, NULL, NULL) = 70    
select(18, [4 6 7], [7], NULL, NULL)    = 1 (out [7])    
sendto(7, "2631A1=31K365365f334370210367202260B33332E3337232423340s21"..., 70, 0, NULL, 0) = 70    
select(18, [4 6 7], [], NULL, NULL)     = 1 (in [7])    
recvfrom(7, "2631r2432F31K365365U10200u236332*Mf316l2252306v254350364"..., 1024, 0, NULL, NULL) = 1024    
select(18, [4 6], [6], NULL, NULL)      = 1 (out [6])    
……    
#这些recv和send就是页面请求的传输过程，ie上显示出来正确的页面了。
返回去查找之前的工单，也确认了222.73.34.25正是该客户之前的源站ip，而后改成219.235.4.17的。
由此看来rinetd虽然可以在conf里写域名，但其对域名的解析，只会在启动的时候执行一次，之后就一直持续对固定的那个ip进行转发了！
<hr />
马后炮的说：这个问题其实被我搞复杂了。因为连接是stream的方式，有一个keepalive的时间，所以完全可以在ie访问的时候用netstat -an|grep :443，就能看到回源的ip，很轻松的就能判定源站ip有问题了——不过这是现在按图索骥，在不知道是源ip不对之前，谁会想到呢~~~
