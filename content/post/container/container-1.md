---
title: "Container研究 - 从头实现系列之一（核心原理）"
date: 2024-10-27T21:41:32+08:00
draft: false
categories:
  - DevOps
tags:
  - Container
---

前段时间工作不忙，又多看了一下容器的一些底层原理，之前一直都知道容器是通过`Linux Namespace`,`CGroup`等原理来实现资源隔离和资源控制的，但是具体的实现不是很清楚，所以写了一个简单的`Container`进程来进行一些原理性的学习。

在实现过程中，发现了有一些有趣的细节，所以记录一下过程。当然也参考了很多现有的资料，附录中会标注。

# 确立目标
在所有工作开展前，需要先确定好目标，哪些是重点需要关注的，哪些是可以忽略的
> [需要关注的内容]
- 首先为`Container`项目起一个名字 `SimpleContainer` --> Commnad(`sc`)
- `Container`需要使用`Linux Namespace`来进行资源隔离
- `Container`需要使用`CGroup`来进行资源限制，包括： CPU/MEM
- `Container`需要支持常见的`Docker`命令，比如：
  - 容器管理: `ps`, `run`, `stop`, `rm`
  - 镜像管理: `ls`, `pull`, `save`, `import`

> [可以忽略的内容]
- 容器镜像格式解析部分，可以利用现有其他开源项目处理，暂不关注
- 不需要关注镜像的`build`,`push`等能力
- 不关注`IO`(`Disk`,`Network`)的资源限制
- 不关注`CRI`,只处理`Container`,不关注`Pod`
- 不关注多种多样的挂载模式

这样，基本上会得到一个比较简单且能运行演示核心能力的 `Container`

因为涉及到的内容比较多，无法通过一个文章来描述，所以预计会分成这几个文章:
- [Container研究 - 从头实现系列之一（核心原理）](./container-1.md)
- [Container研究 - 从头实现系列之二（镜像管理）](./container-2.md)
- [Container研究 - 从头实现系列之三（容器运行时）](./container-3.md)
- [Container研究 - 从头实现系列之四（容器管理）](./container-4.md)
- [Container研究 - 从头实现系列之五（多进程锁）](./container-5.md)

# 核心原理介绍
在实现`Container`之前，需要复习一下`Linux Namespace`以及`CGroup`相关的原理；把涉及到概念都整理一下。

## Linux Namespace
Linux Namespaces(命名空间)是 Linux 内核的一个特性，用于实现进程隔离。主要是这几种命名空间：
- Mount Namespace: 独立的文件系统视图（即挂载列表）
- PID Namespace: 独立的进程空间及PID
- Network Namespace: 独立的网络空间
- IPC Namespace: 独立的进程间通讯，即：消息队列，共享内存，信号量等
- UTS Namespace: 独立的主机名/域名等
- User Namespace: 独立的用户空间（即不同的用户列表）

通过`Linux Namespaces`技术，每个`Container` 可以使用独立的空间，类似一台独立的机器；但是因为还是使用的相同的操作系统内核，和虚拟机的隔离模式又相互区别。

### 如何创建 `Namespace`
创建新的`Namespace`有如下几种方法：
1. 通过 `clone` 函数  
  在创建新进程时，指定需要创建的`Namespace`
  ```c
    // flags: 可用于标识需要创建的`Namesapce`
    pid_t clone(int flags, void *stack, int *ptid, int *ctid, unsigned long newtls);
  ```

2. 通过 `unshare` 函数/命令  
  通过`unshare`函数或者命令，使当前进程进入新的`Namespace`
  ```c
  // flags: 同`clone`函数  ，可用于标识需要创建的`Namesapce`
  int unshare(int flags);
  ```

### 如何进入已有的 `Namespace`
类似`docker exec`, `docker attach`命令，可以通过 `setns`函数进入指定进程所在的 `Namespace`

```c
// fd: 文件 `/proc/[pid]/ns/[namespace]` 的`fd`, 其中：
//   pid: 指定进程ID
//   namespace: 可选值有 `net`, `pid`, ...等，具体对应不同的`namespace`
int setns(int fd, int nstype);
```

### 如何"退出" `Namespace`
进入到某个`Namespace`之后, 就不存在退出这个概念, 但是有2个方法可以达成类似的效果:
1. 再重新进入进程原来的 `Namespace`
2. 当前进程结束即可退出所在 `Namespace`

## CGroup
CGroup（Control Groups 的缩写）是 Linux 内核的一个特性，用于限制、控制和监视进程组的资源使用情况。它可以对一组进程施加资源限制，确保它们不会超过一定的资源使用量.

CGroup的主要功能:
- 资源控制: 限制进程(组)的`CPU`/`Memory`/`IO`等资源
- 优先级管理: 可以为不同的进程组设置不同的优先级，从而让某些进程可以分配更多的资源
- 资源监控: 监控进程组的资源消耗情况
- 资源隔离: 结合`Linux Namespace`技术，形成进程组的资源隔离

### CGroup V1 和 CGroup V2
（待补充）

### 资源分配
(待补充)

## 权限
(待补充)


## RootFS
大家都知道，`Container`使用独立的文件系统,在新的文件系统中，需要包含`rootfs`, 新的`Container`启动后，使用`chroot`切换进程根目录(`/`)到新的`rootfs`所在目录，这个目录其实就是容器的镜像解压之后的目录。

这会产生2个新的问题：
- 一个镜像可能启动多个`Container`,那么需要重新解压
- 进程运行后，会产生新的文件,可能修改/删除原镜像的文件

所以如果按照最原始的方法，每次新的`Container`都重新解压镜像，会产生大量的`IO`，并且有重复拷贝，占用的磁盘空间就会很大。

### Overlay文件系统
`Overlay` 文件系统主要是通过合并多个目录来产生一个新的文件挂载点；通过`Overlay`文件系统可以解决`Container`运行时的磁盘空间占用，以及启动的效率问题。

这里不详细介绍`Overlay`文件系统，具体可以寻找相关的资料阅读。
