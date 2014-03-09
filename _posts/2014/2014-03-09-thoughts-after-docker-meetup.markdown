---
layout: post
title: Docker Meetup 参会总结
category: docker
tags:
  - puppet
  - linux
---

昨天去车库咖啡参加了 Docker Meetup，一共有三位做了分享。

第一位主要演示用法，这个基本都了解；
第二位描述了一下相关生态圈，我自认算是对DevOps工具和动态了解比较多的人了，听完后对这位自称10年前作为运维的Rails开发者不得不说个佩服，知道的真广泛；
第三位是BAE的技术负责人，很诚恳的介绍了自己是怎么从一抹黑的环境开始摸索着搞 PAAS 平台的，波折的选型中一些想法和顾虑也都很坦白。

问答聊天过程中，大家主要纠结两个疑难：

1. docker 和 puppet 会是什么关系？
2. docker 和 kvm 会是什么关系？

这里我个人也稍微写几句我的想法：

docker 和 puppet
==================

docker 无疑是一种非常干净的大规模部署方案。而 puppet 本质是一个配置管理工具（官网说法是通过简洁易懂的DSL描述服务器配置），注意：**这里并没有提到是大规模部署**，事实上 puppet 自己就有好几种完全不同架构设计的部署运行方式。

所以，从概念定义上来说，我不觉得这两者会是一个替代关系。

那么，puppet 目前的用法，如何跟 docker 一起工作呢？从当前技术点上来说有两个不适应：

1. puppet 非常强大的一件事情是 template 系统和 Facts 变量配合达到的灵活性。但是**在 docker 容器里，Facts 变量是不可信的！**
   刚才测试了一下，以 `docker -m 56m run ubuntu facter | grep memorysize` 得到的结果是主机原始大小512m。所以，我们原先习惯的通过 Facts 变量来自动生成最佳配置的方法失效了。
   事实上， docker 官博上关于 metrics 的获取有好几篇文章，也都很明确是从主机上来获取而不是容器内部。
   
2. puppet 的通用运行方式，是 agent 和 master 通过 SSL 加密交互，根据 agent 的 hostname 来查询对应配置。但是目前的 docker 里，hostname 设置(`docker run -h` 参数)是只对容器内部生效的，在容器外部显然无法通过 DNS 反查。
   以 docker 的愿景，一台主机上就应该运行几百个容器，在某个 master 里维护 hosts 列表显然不现实。
   而且从目前看， docker 对容器间更偏向采用 IP 的方式。比如 `-link` 设置的主机，就是在环境变量里提供对方主机 IP。

这两个问题可能更多的不是从技术方面来追求解决它，而是在用法上规避它或者说无视它。

首先，要习惯横向扩展而不是单机提升。
应用压力上来了，第一反应不是“申请提高容器的 memory 限额”这样，而是“再开两个完全一样的容器加入负载均衡”。这就是 fip 工具提供 `fip scale web=2`这种命令的场景吧。
这样就规避了 Facts 变量的问题，反正你只会有一种系统一种配置文件，压根用不上异构和模板技术。

其次，从 Vagrant 的 provision 里学用法。
目前 Dockerfile 的 `RUN` 指令其实很类似 Vagrant 的 provision 中的 shell 实现。而 Vagrant 的 provision 实现还包括 puppet、chef等等。所以我们或许能琢磨一种替代 RUN 的优雅的 docker 镜像构建方式。
比如 [puppet-librarian](http://librarian-puppet.com/) 的做法或许就是一个思路。Dockerfile 里 只需要 `ADD` 一个 Puppetfile，然后 `RUN` 一个 librarian-puppet 命令完成容器内一切配置。

docker 和 kvm
===================

前面提到了 docker 中系统性能数据的采集问题。这或许就是容器和虚拟化一个差别问题，即便未来大家越来越普遍采购 ops 产品而不是自己搭建监控系统，也不会完全放心的认可主机提供商的系统性能数据，至少也还有一个核算和度量问题。

此外，容器目前比较普遍的一个用法，是一个容器里只跑一个业务进程。一个完整的业务系统的每个部分，都通过分散的各种服务相互走 API 来调用。迁移到这种环境，对传统业务显然是有重构压力的。而 kvm 虚拟机则基本没有这个问题。
当然，最近也已经看到文章在讨论单个 docker 容器里运行多个不同业务进程的问题。这方面，如果 docker 真有心往替代 kvm 努力，除了网络方面的硬技术外，这个 PAAS 层已经养成的思维逻辑也需要改变。

OK，说到网络问题。目前 docker 的运用，通过 `-link` 来连接，或者通过 etcd、serf 这类工具来获取想要连接的其他服务器的 IP，都是一种在相同主机上的应用。
看 `pipework` 和相关文章，似乎 `openswitch` 也只是做单个宿主机之上的 VLAN 划分管理？ SDN 到底是怎么回事，我现在还完全不了解。
