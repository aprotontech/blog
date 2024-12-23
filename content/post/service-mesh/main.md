---
title: "Service Mesh 网络安全(Traefik vs Linkerd vs Istio)"
date: 2024-11-28T21:05:03+08:00
draft: false
categories:
  - DevOps
tags:
  - Kubernetes
  - Service Mesh
---

# Service Mesh

最近项目期望通过`Service Mesh`提升集群通讯的安全性，之前虽然有一些粗浅的了解，但是不足以用来进行选型，所以重新学习了一下，这里做一些记录。

借鉴 `Service Mesh`, 可以很好的管控通讯的安全风险：
- 通讯内容加密: 模块(Pod)间使用HTTPS(or TLS)加密通讯
- 通讯流量管控: 模块(Pod)间的流量受到管控, 任一模块(Pod)只允许指定的模块(Pod)访问
- 入口收敛: 使用 `Ingress` 收口外部访问集群环境的入口
- 出口管理: 只能允许访问特定的外部服务
- 流量存证: 日志存证


## 核心能力
众多的`Service Mesh`软件中, 各自侧重的能力不太一样, 总结下来, 一般`Service Mesh`主要是一下核心能力：

| 核心能力 | 项目需求 | 简介 |
| - | - | - |
| 服务发现 | &#10003; | 一般指的是`动态`服务发现, 自动发现网络中的服务(如`K8s`中的`Service`等) |
| 反向代理 | &#10003; | 外部流量访问应用(如`Pod`)的代理 |
| 正向代理 | - | 应用(如`Pod`)访问其他服务的代理 |
| 负载均衡 | &#10003; | 为了保障多个后端服务实例负载平衡, 流量分配到后端实例的方式, 一般有的方法：轮询, 随机, 权重等 |
| 超时&重试 | | 请求超时以及支持自动重试 |
| 路由 | &#10003; | 如何将流量分发到不同的后端服务实例上, 比如根据 `HTTP`协议的 `Host`or`Path`<br/>PS: 和负载均衡不一样, 这里的后端服务实例可能并不是对等的 |
| 中间件 | | 支持开发人员在请求中增加处理逻辑(中间件), 比如: 鉴权, 请求重写等 |
| HTTPS证书 | &#10003; | 是否支持管理HTTPS证书(以及搭配`Let’s Encrypt`), 提供HTTPS服务 |
| MTLS通讯 | &#10003; | 双向TLS通讯(在HTTPS基础上也验证客户端身份) |
| Metric&Monitor | &#10003; | 提供监控 `Metric` 供`Promethues`等工具采集 |
| Trace | | 跟踪请求链路 |
| 日志 | &#10003; | 记录请求日志 |
| 自动注入代理 | - | 自动在应用(如`Pod`)注入`SiderCar`代理流量 |
| 通讯授权 | &#10003; | 应用(`Pod`)间访问授权策略 |
| Api Gateway | | 应用程序编程接口网关, 处理所有进出应用的`API`请求 |
| 出口流量限制 | | 限制集群应用(如`Pod`)访问外部服务（比如： 公网上某个接口） |
| 零信任 | | 从不信任任何网络，始终验证，无论来源于内部还是外部 |

> `-` 代表可能因为是底层能力，项目业务层并不关注; 空白代表暂时不需要

还有一些暂不使用的其他扩展功能，比如：
- 流量复制, 流量重放, A/B测试
- 多协议端口合并(HTTP/GRPC,HTTPS/GRPCS 使用同一个端口)

# Service Mesh 开源项目

## High-Level 对比
目前开源常用的 `Service Mesh` 项目, 以及对比情况如下:

| | Istio | Traefik | Linkerd |
| - | - | - | - |
| Star | 36.1K | 51.4K | 10.7K |
| Issue | 20K | 6K | 4K |
| Contributor | 1070 | 825 | 366 |
| Ingress | &#10004; | &#10004; | - |
| 数据面 | Envoy(C++) | golang | rust |
| 控制面 | golang | - | golang |
| 通讯授权 | &#10004; | - | &#10004; |
| 复杂度 | +++ | ++ | ++ |

> Star History
> [![Star History Chart](https://api.star-history.com/svg?repos=linkerd/linkerd2,traefik/traefik,istio/istio&type=Date)](https://star-history.com/#linkerd/linkerd2&traefik/traefik&istio/istio&Date)

## Traefik
Traefik 是一个现代的、开源的反向代理和负载均衡器, 旨在简化和优化微服务架构的管理与部署。它特别适合于容器化环境, 如 Kubernetes、Docker Swarm、Mesos等, 能够动态地发现和配置服务。

`Traefik` 相比其他 `Service Mesh`, 他核心的能力主要还是集中在 `Ingress`,  即入口流量的代理, 他并不关注应用(`Pod`)与应用(`Pod`)之间的通讯；除此之外, 基本上该有的功能都有。
因为只关注`入口代理`, 整体来说比较简单, 简洁； 他的核心架构如下：

![traefik-architecture](https://github.com/traefik/traefik/raw/master/docs/content/assets/img/traefik-architecture.png)

核心概念:
- Providers: 发现您的基础设施上的服务(类型, Host, 健康...)
- Entrypoints: 侦听传入流量(端口, ...)
- Routers: 分析请求(主机, 路径, 标头, SSL, ...)
- Services: 将请求转发给您的服务(负载平衡, ...)
- Middlewares: 可以根据请求更新请求或做出决策(身份验证, 速率限制, ...)

整体链路如下
![pipiline](https://doc.traefik.io/traefik/assets/img/middleware/overview.png)

## `Linkerd`
`Linkerd` 是一个开源的服务网格(`Service Mesh`), 旨在简化微服务架构中的服务间通信和管理。它提供了一层透明的基础设施，使得开发人员可以更轻松地处理服务的安全、可靠性、可观察性和故障恢复等方面的问题。
`Linkerd2`是 `Linkerd` 的全新版本，首次发布于 2019 年。它被从头构建，专为 `Kubernetes` 生态系统而设计。 是目前的主要版本。

`linkerd`的核心原理是基于`iptables`来管理流量，在需要代理的`Pod`中自动注入2个`Container`:
- linkerd-init: 它是一个`init container`，执行`iptables`命令，映射出入流量到`linkerd-proxy`
  如果已经使用了`Linkerd CNI Plugin`，则不需要这个容器
- linkerd-proxy: 他是一个`sider container`，实际的数据流量代理

> `Linkerd` 有几个需要关注的点：
> - `Linkerd` 数据面由 `Rust` 编写: 性能/安全性相比`istio`较好
> - `Linkerd` 数据面性能比`istio`好
> - `Linkerd` 并不直接支持`Ingress`, 需要搭配其他`Ingress`控制器实现`Ingress`能力

核心架构如下:

![linkerd-architecture](https://linkerd.io/docs/images/architecture/control-plane.png)

> 通过`Linerd`加密并认证流量参考： [linkerd(待补充)](../linkerd)

## `Istio`
`Istio` 是一个开源的服务网格平台，旨在简化和增强微服务架构的管理。服务网格是一种基础架构层，提供了微服务间的通信、监控、和安全等功能，而不需要更改微服务的代码。

`Istio` 虽然最初是`Lyft`开发，但是后面`Google`等也公司也加入其中，算是`K8s`"官方"的`Service Mesh`组件，功能强大而且全面 ，扩展性非常强(只有你想不到，没有它做不到)，当然带来的后果就是比较复杂，加上`envoy`丰富的配置，理解成本比较高。

从使用规模上说，它目前使用最广泛的`Service Mesh`开源组件。下图是来自于2020年`CNCF`的[调查](https://www.cncf.io/wp-content/uploads/2020/08/CNCF_Survey_Report.pdf)。
![2020调查](https://cloudnative.to/blog/service-mesh-comparison-istio-vs-linkerd/13816813-1596629136427_hu16095317518166807311.webp)

核心架构如下（看起来和`linkerd`基本上一样）:
![istio-architecture](https://istio.io/latest/zh/docs/ops/deployment/architecture/arch.svg)

## Consul
Consul 是一个由 HashiCorp 公司开发的开源软件，最初发布于2014年5月，Consul 的发展始于 HashiCorp 公司内部的一个项目，旨在 解决其在构建云基础设施时遇到的服务发现和配置管理问题。随着发展，陆续集成了更多的能力，成为了一个全面的服务网格解决方案。 所以它的`Service Mesh`并不像是一个带有明显技术理念的产品，更像是一个公司"售卖"产品，解决公司产品售卖中的一环，如果之前 已经使用`HashiCorp`公司的产品，可以自然引入`Consul Connect`(它的`Service Mesh`项目名)，否则没有太大的必要。

# 结论
结合上述的一些介绍, 每个`Service Mesh`开源项目侧重点, 特点都不太一样, 具体的选择需要结合项目的实际情况来分析;
不过我们可以先进行一些简单的归纳:
- 如果只是想使用流量入口管理能力(`Ingress`), 推荐使用 `traefik`
- 如果对资源消耗有严格要求，且没有太多复杂的功能定制需求， 推荐使用 `linkerd2` + `traefik`
- 如果是一个比较大的项目，期望通过一套方案解决所有的网络问题，推荐使用 `istio`
- 如果需要管理出口流量，推荐使用`istio`

# 附录
- [traefik](https://github.com/traefik/traefik)
- [linkerd](https://github.com/linkerd/linkerd2)
- [istio](https://github.com/istio/istio)
- [traefik docs](https://doc.traefik.io/traefik/)
- [linkerd docs](https://linkerd.io/2.16/overview/)
- [Istio、Linkerd和Cilium的性能比较](https://yylives.cc/2024/05/22/comparison-of-service-meshes/)
- [Linkerd vs Istio](https://buoyant.io/linkerd-vs-istio)
- [Service Mesh对比: Istio与Linkerd](https://www.kubernetes.org.cn/8220.html)
- [Istio vs. Linkerd vs. Consul](http://101.43.184.235/index.php/2022-02-25-08-19-05/15-servicemesh/14-istio-vs-linkerd-vs-consul)
- [Traefik和Nginx的详细对比](https://cloud.tencent.com/developer/article/2401589)