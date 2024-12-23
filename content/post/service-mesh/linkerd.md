---
title: "Service Mesh 之 Linkerd"
date: 2024-11-28T21:28:09+08:00
draft: true
categories:
  - DevOps
tags:
  - Kubernetes
  - Service Mesh
---

# Install
参考 [官方文档](https://linkerd.io/2-edge/getting-started/) 进行安装

核心命令:
```bash
# install `linkerd` command
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh
export PATH=$HOME/.linkerd2/bin:$PATH
linkerd check --pre

# install linkerd resources
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
# option: linkerd check
```

# Linkerd Authorization Policy

Linkerd 支持流量加密认证，即：
- 对于指定`Pod`(eg: `minio`), 可以控制哪些流量(`Pod`)可以访问它
- 其他`Pod`访问它时，流量通过 `MTLS` 加密

当然 `Linkerd` 还有其他流量认证的方式，但是这里只介绍，项目可能用到的部分

## 业务流量加密认证
`Linker`有以下几个概念用于流量加密认证

| CRD | 描述 |
| - | - |
| Server | 如其名相当于流量的目标位置，定义一组`Pod`以及其上的一个`Port`, 可以类比`K8s`原生的`Service` |
| NetworkAuthentication | 基于请求来源IP认证（用于来自集群外部流量访问认证，或者`K8s`的各类探针访问），这部分流量目前并 不会加密 |
| MeshTLSAuthentication | MTLS加密流量, 关联流量源头(`Pod`)的`ServiceAccount` |
| AuthorizationPolicy | 将`Server`和`MeshTLSAuthentication`关联起来 |


### 示例演示
下面的示例，是通过`minio`客户端(`mc`)来访问`minio`的服务

<details>
<summary>示例minio配置</summary>

> 1. MinIO Server Deployment
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minio-test-server
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: minio-test-server
  namespace: minio-test-server
  labels:
    app: minio
    project: mytest
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: minio-test-server
  labels:
     app: minio
spec:
  selector:
    matchLabels:
      app: minio
  serviceName: minio
  replicas: 1
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled
        config.linkerd.io/default-inbound-policy: deny
      labels:
        app: minio
        project: mytest
    spec:
      containers:
      - name: minio
        envFrom:
        - secretRef:
            name: minio-admin-config
        image: minio/minio:RELEASE.2024-11-07T00-52-20Z
        args: ["server", "/data"]
        ports:
        - name: minio
          containerPort: 9000
      serviceAccountName: minio-test-server

---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio-test-server
spec:
  selector:
    app: minio
  ports:
  - name: service
    protocol: TCP
    port: 9000
    targetPort: 9000
  type: ClusterIP
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-admin-config
  namespace: minio-test-server
type: Opaque
stringData:
  MINIO_ROOT_USER: "minio"
  MINIO_ROOT_PASSWORD: "IPFvslzI1pVCrfbO"
```

> 2. Minio Test Client
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minio-test-client
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: minio-test-client
  namespace: minio-test-client
  labels:
    app: minio
    project: mytest
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio-client
  namespace: minio-test-client
  labels:
     app: minio-client
spec:
  selector:
    matchLabels:
      app: minio-client
  replicas: 1
  template:
    metadata:
      annotations:
        # auto insert linkerd sider-car
        linkerd.io/inject: enabled
      labels:
        app: minio-client
        project: mytest
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2024-11-07T00-52-20Z
        envFrom:
        - secretRef:
            name: minio-admin-config
        command:
        - sh
        - -c
        - |
          set -ex
          mc alias set myminio http://minio.minio-test-server.svc:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
          while true; do
            if [ $(mc ls myminio | wc -l) -eq 0 ]; then
              mc mb myminio/test-bucket
            fi
            mc ls myminio/
            sleep 30
          done

      serviceAccountName: minio-test-client
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-admin-config
  namespace: minio-test-client
type: Opaque
stringData:
  MINIO_ROOT_USER: "minio"
  MINIO_ROOT_PASSWORD: "IPFvslzI1pVCrfbO"
```

> 3. 创建网络认证
```yaml
apiVersion: policy.linkerd.io/v1beta3
kind: Server
metadata:
  name: minio-server
  namespace: minio-test-server
spec:
  podSelector:
    matchLabels:
      app: minio
  port: minio
---
apiVersion: policy.linkerd.io/v1alpha1
kind: MeshTLSAuthentication
metadata:
  name: minio-client-auth
  namespace: minio-test-server
spec:
  identityRefs:
    - kind: ServiceAccount
      name: minio-test-client
      namespace: minio-test-client
---
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: minio-auth-policy
  namespace: minio-test-server
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: minio-server
  requiredAuthenticationRefs:
    - name: minio-client-auth
      kind: MeshTLSAuthentication
      group: policy.linkerd.io
```

</details>

### QA
1. 如何验证minio服务
> 成功示例
```bash
[root@test-tools-657748779f-5w88z /]# mc alias set myminio http://minio.minio-test-server.svc:9000 minio IPFvslzI1pVCrfbO
Added `myminio` successfully.
[root@test-tools-657748779f-5w88z /]# mc mb myminio/test-bucket
Bucket created successfully `myminio/test-bucket`.
```

> 失败示例
当minio server启动之后，如果在其他`Pod`访问minio会失败
```bash
[root@test-tools-657748779f-wm2vd /]# mc alias set myminio http://minio.minio-test-server.svc:9000 minio IPFvslzI1pVCrfbO
Added `myminio` successfully.
[root@test-tools-657748779f-wm2vd /]# mc mb myminio/test-bucket
mc: <ERROR> Unable to make bucket `myminio/test-bucket`. Access Denied.
```

原因是 `minio-test-server`的`annotations`增加了`config.linkerd.io/default-inbound-policy: deny`，默认会拒绝所有流量。

> PS: 有一点很奇怪，虽然创建`bucket`的时候失败了，但是执行 `mc alias` 时却可以检查账密是否正确. 是因为`linkerd`自动识别 了`s3`的协议，做了适配吗？

2. 关于`minio`服务的`annotations`
  - linkerd.io/inject: enabled
    用于自动将`linkerd`的sider-car注入，这里是针对`Pod`主动注入，可以直接在`Namespace`上增加`annotation`，这样`namespace`下的资源不用手动增加； 参考 [Automatic Proxy Injection](https://linkerd.io/2-edge/features/proxy-injection/)
  - config.linkerd.io/default-inbound-policy: deny
    * 用于默认情况下流量的认证，这里是默认拒绝流量（只允许创建的`AuthorizationPolicy`的`源头`才可以访问）
    * 如果不设置该`annotation`，那么创建的`Pod`在没有创建对应的`Server`是允许访问的; 一旦创建了`Server`后，`Pod`就不可以访问。（当然这一段话，并不绝对，因为只考虑了`Pod`的配置，了解官方文档可以看到更全面的信息。）
    * `default-inbound-policy`也可以配置在`Namespace`上，这样就不用调整原有部署模版；也可以在安装`linkerd`时配置，具体可以参考官方文档。
    * 参考链接： [Configuring Per-Route Authorization Policy](https://linkerd.io/2-edge/tasks/configuring-per-route-policy/)

## Probe等认证
当创建好`Server`或者`default-inbound-policy`默认拒绝流量时，会导致`Kubelet`自动检查Pod状态的请求会失败，比如：
```yaml
kind: Deployment
apiVersion: apps/v1
spec:
  template:
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2024-11-07T00-52-20Z
        readinessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
        ports:
        - name: minio
          containerPort: 9000
...
```
K8s因为无法访问`/minio/health/live`接口而失败，所以需要使用`linkerd`的`NetworkAuthentication`来进行认证。更多请参考 [官 方文档](https://linkerd.io/2-edge/tasks/configuring-per-route-policy/)

<details>
<summary>NetworkAuthentication示例</summary>

```yaml
apiVersion: policy.linkerd.io/v1alpha1
kind: NetworkAuthentication
metadata:
  name: authors-probe-authn
  namespace: minio-test-server
spec:
  networks:
  - cidr: 0.0.0.0/0
  - cidr: ::/0
---
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata:
  name: authors-probe-policy
  namespace: minio-test-server
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: minio-server
  requiredAuthenticationRefs:
    - name: authors-probe-authn
      kind: NetworkAuthentication
      group: policy.linkerd.io
```

</details>

> **安全注意**: 上述示例对`minio`的请求打开了所有的来源流量，会导致上文中的`MeshTLSAuthentication`使用作用，从而出现安全风险，可以有两个方法进行加固:
> - [推荐] 使用`HTTPRoute`加固, `NetworkAuthentication`只允许`GET /minio/health/live`请求
> - 小心设置来源`IP`, 只允许来自于`kubelet`的流量访问


## `Linkderd` 限制访问集群外部服务
`linkerd`不支持该能力

## `Traefik`和`Linkerd`的集成
（待补充）