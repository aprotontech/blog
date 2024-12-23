---
title: "Service Mesh 之 Istio"
date: 2024-11-28T21:28:19+08:00
draft: true
categories:
  - DevOps
tags:
  - Kubernetes
  - Service Mesh
---

# Install
`istio` 有多种安装方法，详细参考 [官方文档](https://istio.io/latest/docs/setup/install/)
这里仅介绍`helm`的安装方法:

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingress istio/gateway -n istio-ingress --wait --create-namespace
```

# Authorization Policy
`Istio` 通过 `AuthorizationPolicy` 支持流量认证，通过 `PeerAuthentication` 来严格控制应用程序只接受`MTLS`流量。

从 `CRD` 的设计来讲，相比`linkerd`的3个`CRD`来定义认证，`istio`一个`CRD`(`AuthorizationPolicy`)即可同时包含认证的`源头` 和`目标`的设定，相对来讲，简单清晰一点。同时`AuthorizationPolicy`不仅仅可以定义白名单，还可以定义黑名单，自定义认证服务 ，功能上强大一些。

| CRD | 意义 |
| - | - |
| AuthorizationPolicy | 定义流量认证的`source`,`to`,`action`等 |
| PeerAuthentication |  |

## 业务流量认证
同`linkerd`, 演示的服务也选择`minio`, `server`/`client`部分的部署模版基本上一样，除掉:
- 原来`linkerd`相关的`annotations`去除
- 新增`istio`相关的`label`(`sidecar.istio.io/inject=true`)

所以这里就不单独列`minio-server`,`minio-client`的`yaml`部署示例模版了，只提供`auth`的部署模版

<details>
<summary>istio认证示例</summary>

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-minio-test-client
  namespace: minio-test-server
spec:
  action: ALLOW
  selector:
    matchLabels:
      app: minio
  rules:
  - from:
    - source:
      principals:
      - cluster.local/ns/minio-test-client/sa/minio-test-client
```
</details>

## `istio` 限制访问集群外部服务
待补充


# 附录
- [在 istio 中限制 namespace 访问外部资源](https://cloud.tencent.com/developer/article/1674548)