---
title: "Container研究 - 从头实现系列之四（容器管理）"
date: 2025-07-06T14:29:28+08:00
draft: false
categories:
  - DevOps
tags:
  - Container
---

# 容器管理


## 容器描述信息

在 [从头实现系列之三（容器运行时）](./container-3.md) 中，我们介绍了如何启动容器，也提到一个数据结构 `ContainerMeta`，这个就是用于保存容器信息的

大部分的信息基本上从变量名中即可看出，所以只简单介绍一下

```go
type ContainerMeta struct {
	Name        string    `json:"name"`             // 容器名
	ProcessID   int       `json:"processId"`
	ContainerID string    `json:"containerId"`
	Image       string    `json:"image"`
	Command     string    `json:"command"`
	Created     time.Time `json:"created"`
	Status      string    `json:"status"`
	Ports       string    `json:"ports"`            // 容器映射的Port，我们实际没有使用
	Sandbox     string    `json:"sandbox"`
	Overlay     *Overlay  `json:"overlay"`
}

type Overlay struct {
	Working    string `json:"working"`
	Upper      string `json:"upper"`
	MountPoint string `json:"mountPoint"`
}

```


## 容器管理命令

基于上述数据结构，我们直接简单的创建一个文件`var/container.json`，保存一个 `ContainerMeta` 列表，即可将相关容器信息管理起来。

那么相关的命令就比较简单的：

- `container list`: 读取文件`var/container.json`，打印所有的容器

- `container stop`: 从`var/container.json`找到指定的容器，Kill进程组

    > 先使用 `SIGTERM`, 如果5s后进程没有结束，再发送 `SIGKILL` 命令

- `container rm`: 从`var/container.json`找到指定的容器，停止后，解除挂载，并删除`Sandbox`目录
 