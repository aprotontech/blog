---
title: "Kind - Startup"
date: 2024-10-28T21:36:56+08:00
draft: true
categories:
  - DevOps
tags:
  - Kind
  - Container
---


# Kind 学习

最近需要搭建私有化`K8s`集群，为了验证集群的高可用能力，使用`Kind`来模拟集群，下面记录安装过程和一些遇到的问题。

## Kind介绍


# Kind 安装
## 创建示例集群
下面的示例创建一个具备1-`master`,3-`worker`的集群。
```yaml
简单配置
```

创建命令
```bash
kind create cluster --image kind/node:v1.31.0 --retain --name kuper --config cluster.yaml
```

遇到的问题:
1. 一直在
通过查看`kubelet`日志发现是因为没有自动创建`cgroup`
> xxx日志
修复：
```bash
mkdir -p xxxx
```

## 挂载本地存储


## 配置ApiServer签名域名
测试的机器是在阿里云上，本地使用`Lens`来访问集群，但是默认配置情况下，会出现证书签名的问题
```    
```

通过如下配置解决：
```yaml
增加内容
```

## 支持镜像代理
为了加速`Containerd`的镜像拉取，需要配置一下镜像代理，配置方法如下：
```yaml
增加内容
```


## 最终的集群配置


```yaml
完整的集群配置
```
