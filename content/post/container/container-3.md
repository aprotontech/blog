---
title: "Container研究 - 从头实现系列之三（容器运行时）"
date: 2025-07-06T13:26:46+08:00
draft: false
categories:
  - DevOps
tags:
  - Container
---

# 创建容器

## 前言
容器的核心原理，在 [Container研究 - 从头实现系列之一（核心原理）](./container-1.md) 中已经有了介绍， 核心就是：
- Namespace: 进行资源隔离； 让容器内外看到不一样的文件系统，进程ID空间等等
- CGroup: 进行资源控制； 限制容器可以使用的CPU/MEM等
- Cap： 进行权限管控； 限制容器可以调用的系统命令


## 容器的启动过程
在代码 [run_linux.go](https://github.com/aprotontech/container/blob/main/container/run_linux.go) 中，我们列出了一个典型的容器启动过程； 核心主要是：

```shell
ContainerRunCommand
    image.GetImage          # 根据需要运行的容器镜像，找到其镜像文件
    buildOverlaySandbox     # 创建容器运行所需要的`overlay`文件系统
                            # 核心主要是创建3层目录： 镜像解压后的目录，容器的工作目录，最终容器看到的`/`目录
    buildProcessCmd         # 根据镜像的Entrypoint/CMD等，以及容器启动命令，构建容器的启动命令行
                            # 这里我们就简化了，只考虑了`Entrypoint`
    reexec.Command          # 启动命令，代码中，我们通过syscall.SysProcAttr创建了新的`Namespace`, `IPC`空间, `PID`空间
                            # 这个函数比较重要，他的工作类似于`C`中的`fork`函数，他的作用就是创建一个新进程调用`container.Run`函数
                            # 所以新进程并不是直接使用`buildProcessCmd`中生成的`Cmd`来启动的
        [container.Run]         # 容器首进程的执行函数

            buildNetworkEnv     # 第一步： 创建一些网络相关的配置；这里我们没有创建新的网卡，分配IP，只是为新容器分配了`HostName`, 设置一些默认的地址， 设置`DNS`信息
            buildFileSystem     # 第二步： 创建一些挂载点，比如: /dev, /proc 等等；因为系统会用到这些挂载点。 因为当前子进程已经在新的`NS`中，所以这些挂载点，并不会影响原来的系统（即：外步看不到这些新的挂载点）
                                #      ： 通过`chroot`将当前目录切换为文件系统的 `/`， 至此后续看到的文件系统根目录就不再是原来的目录
            buildUser           # 第三步： 如果容器指定了运行用户，则切换到对应的用户
            syscall.Chdir       # 第四步： 切换进程的工作目录到容器的`Workdir`
            syscall.Exec        # 第五步： 加载实际`Cmd`到内存，并跳转执行
    SetContainerCgroup      # 设置进程的`CGroup`,即CPU/MEM限制
                            # 根据`CGroup`的原理，这里其实就是创建一些文件即可。具体需要理解`CGroup`的具体原理了
    childcmd.Wait           # 等待子进程(容器主进程)结束
```

结合上面的工作流程来看代码，实际上还是比较简单的，我们在启动子进程时设置新的`NS`，然后在新启动的子进程中，进行一些"容器"的初始化操作，然后加载实际的容器命令行来执行即可。

其他需要注意的：
- 如果要考虑网络，还是比较复杂的，这里只是简单处理，直接使用了`Host`网络
- 代码中没有考虑权限`Caf`的一些设置，这个也是类似`CGroup`，只需要在指定位置写入一些文件即可

此外，代码中还有一项上文没有介绍的，即`ContainerMeta`，这个是用来保存容器的一些信息，父/子进程可以基于它来传递一些信息，此外一些其他管理命令也可以使用这个文件来对容器进行一些操作。

## 命令包装

基于 `cobra.Command` 可以很方便包装出来一个 `container run` 命令，所以这里不赘述了，可以查看代码 [container.go](https://github.com/aprotontech/container/blob/main/container/container.go)



# 附录
