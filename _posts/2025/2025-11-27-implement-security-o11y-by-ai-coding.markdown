---
layout: post
theme:
  name: twitter
title: 大模型编程实录：复刻安全可观测性的 DependencyDiscovery 功能
category: 安全
tags:
  - 可观测性
  - AI编程
---

大模型编程已经流行一段时间了，一般拿出来比拼的都是怎么写前端。每次厂商更新发布，都喜欢炫一炫页面生成如何如何丝滑。但在此之外，对现有项目的功能迭代，大模型能力如何，就不是那么好展现了。我之前主要也是用大模型做一些临时性的小开发，用完即丢。这次突发奇想，打算给现有项目做个增量开发迭代，看看实际表现如何。

作为可观测性的产品经理，最近看到国外友商 Splunk 发布了一个叫做[“Secure Application on Splunk Observability Cloud”]https://www.splunk.com/en_us/blog/observability/fix-faster-ship-safer-with-secure-application-on-splunk-observability-cloud.html)的功能，大概作用是当应用程序启动时，javaagent 自动扫描应用的依赖库信息，并作为一种特定的 span 上报到后端，和漏洞库关联分析。更详细的技术细节，则可以看另一个国外友商 Oracle APM 产品的[“Application Dependency Vulnerability”](https://docs.oracle.com/en-us/iaas/application-performance-monitoring/doc/view-application-dependency-vulnerabilities.html)功能介绍（这么偏门的文档，当然是 gemini deep research 找出来的）。我们就以这个功能为实现目标，让大模型试试看。

![Secure Application on Splunk Observability Cloud](/images/splunk-secure-application-2.webp)
![Secure Application on Splunk Observability Cloud (AVIF)](/images/splunk-secure-application-1.avif)

首先下载一个开源的 javaagent 实现。这里我们选择 elastic/elastic-otel-java，主要是考虑到作为 opentelemetry 的厂商发行版，很可能比默认的 open-telemetry/opentelemetry-java-instrumentation 多一些外部扩展开发，能给大模型做参考。最后花费了 10 次 Trae AI Builder 会话，完成了这次开发。

总结一下：

| 会话首次提问 | 会话的成果 | 人工介入 |
| --- | --- | --- |
| 总结本项目的源代码逻辑，并尝试编译。 | 输出代码总结文档；编译失败，反馈原因是 JDK14 版本低于要求的 17 | 人工执行大模型提供的 jdk 升级命令 |
| 编译报错，我不想要 profiling 功能也不想安装 docker 环境，能不能跳过？ | 持续 13 次报错+调整，去掉了build.gradle.kts文件中各种依赖 docker 的 jni 要求，采用./gradlew build -x test 跳过测试步骤 | 使用 -x test 跳过测试 |
| `https://docs.oracle.com/en-us/iaas/application-performance-monitoring/doc/view-application-dependency-vulnerabilities.html` 我希望在项目中实现类似这个网页上介绍的功能，请你分析拆解需求，形成规划说明书。以便后续开发。 | 设计了一个横跨 3 周的工作计划，包括 MVP 的功能范围和实现类清单。 | 请你结合目前项目的情况再考虑。本项目仅涉及 javaagent 部分，不涉及后端的漏洞库集成、查询、和展示等。所以开发规划的重点是在如何具体地实现依赖发现和 PURL span 生成。 |
| 按照 TODO.md 开始第一个 MVP 版本开发。 | 1次编译失败，调整后完成开发。 |   |
| 我下载了一个spring-petclinic-4.0.0-SNAPSHOT.jar，并尝试用java -javaagent:elastic-otel-javaagent-1.7.1-SNAPSHOT.jar -jar spring-petclinic-4.0.0-SNAPSHOT.jar运行起来了。但没看到依赖发现的 log 打印到控制台上。请问你的实现里，我应该如何看到这些 span 是否创建成功了呢？ | 各种加 system.put 日志 | 每次测试运行输出会有一堆尝试连接 otelcol 失败的报错，干扰大模型分析。干脆自己去手动下载了一个 otelcol 启动起来。 |
| otelcol 接受到了 log 和 metric，但是依然没有 dependencydiscovery 的 trace | 修复 tracer set 问题 | 大模型跑着跑着，又开始直接./gradlew build，然后反复修 profiling 的 test。终止以后手动执行-x test编译。 |
| Terminal#567-571 尝试运行编译好的程序，结果发现日志记录显示依赖发现为 0.这不可能啊。明明前一行日志里还看到调用 jdbc 了。 | 发现scanUrlClassLoader只处理 file:协议，而且不遍历嵌套JAR。 | |
| 我把测试运行的spring-petclinic项目源代码也挪到当前目录里了，你可以分析一下这个源代码，看看这个项目编译成 jar 运行以后，应该有哪些依赖应该被我的 otel-java agent 发现。 | 发现实际url里有`/!`也有`!/`，调整切割规则 | 一直在反反复复改，主动停下来，切换大模型 gemini-2.5-flash 为自己付费的 kimi-k2，成功。  |
| `app42_example.log` 这是尝试插码 springboot 的 demo，得到的记录。请你审查一下，提出改进意见。 | 优化 PURL 格式清洗规则；合并每个依赖库的独立 span 为统一的 traceid；增加批量处理和缓存 | |
| 请你清理 `/Users/rizhiyi/Downloads/gitdir/elastic-otel-java/custom/` 目录下我们编写的依赖发现源代码中，为了 debug 加入的各种不必要的调试输出。 | | |

最终，大模型预计 3 周的任务，2 天内完成了。通过表格标红的两个关键位置可以看到，实际上阻碍大模型要花整整 2 天才能开发完毕的主要因素是：我之前已经把 gemini-2.5-pro 的额度用完了，所以一开始用免费的 gemini-2.5-flash 跑。flash 模型真的不行……本地 MacOS 开发环境不完善，浪费了大量时间在和需求无关的地方——当然我 Trae 用的不多，后来才发现可以通过配置项目级 rule 的方法，强制大模型采用特定的编译命令。

这次大模型编程的最终成果，大概 2k 行 java 代码，已经上传到 github 上，对“安全可观测性”感兴趣的读者可以查看：<https://github.com/chenryn/elastic-otel-java/commit/9f5518981764b1a20c2c7a3031939fb3135f7faa>。
