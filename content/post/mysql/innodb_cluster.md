---
title: "Mysql InnoDB Cluster"
date: 2024-10-31T21:37:59+08:00
draft: false
categories:
  - DevOps
tags:
  - Mysql
  - Kubernetes
---

# Mysql InnoDB Cluster

近期因为工作原因研究了一下高可用的`Mysql`，虽然使用`Mysql`很多年了，也对一些`Mysql`的高可用方案有一些了解，但是深入去看这一块后，还是学习了很多新的东西。写个文章记录一下。

## 简介

`Mysql InnoDB Cluster` 是`Mysql`官方开发的一套高可用方案，基于`MySQL Group Replication`实现。



### `MySQL Group Replication`
组复制`MySQL Group Replication`（简称`MGR`）是`MySQL`官方在已有的Binlog复制框架之上，基于`Paxos`协议实现的一种分布式复制形态。
组复制的数据强可靠性来源于`Paxos`协议的多数派原则，即当多数派收到事务的`Binlog`后，事务才能在各节点提交。这保证了在多数派可用的情况下，任何节点故障都不会导致数据丢失。

相比其他模式，`MGR`模式简单，不依赖于复杂的分布式数据存储协议，只是在`Sql`本身上依赖`Paxos`协议确保多数机器得到执行，即使在极端情况下，只要能有一台机器正常，仍然可以通过它快速恢复服务（当然只能回到传统的单机的模式了）。

特性 | `MGR` | 半同步复制 | 异步复制
------- | -------- | -------- | --------
数据可靠性 | ★★★★★ | ★★★★ | ★
数据一致性 | 保证主备数据一致性 | 不保证 | 不保证
全局事务一致性 | 支持 | 不支持 | 不支持


### 多主模式和单主模式
多主模式相比单主模式，任意节点故障都可能会导致集群抖动（短时间不可用），且有一些限制，所以选择单主模式是比较合适的。
参考架构图：

![innodb_cluster_overview](https://dev.mysql.com/doc/refman/8.4/en/images/innodb_cluster_overview.png)


### InnoDB Cluster特点
InnoDB Cluster特点: 
- 自动故障转移: 当主节点出现故障时，InnoDB Cluster可以自动选择一个从节点提升为新的主节点。
- 数据一致性: 通过Group Replication保证了数据的一致性。
- 简化配置: 使用MySQL Shell进行简化的配置和管理。
- 读写分离: 通过MySQL Router实现读写分离，提高系统性能。
- 集成监控: 提供集成的性能监控和告警功能。

缺点:
- InnoDB Cluster早期版本集群稳定性差一些(分布式Paxos协议细节问题很多),建议使用8.0之后的版本
- 多主模式下，不支持一边对一个表进行DDL, 另一边进行更新，以及在不同主下进行DDL
- 组复制建议，事物隔离级别，read commit
- 因分布式协议设计，最少3个节点才比较合适；当故障的机器数少于一半时，集群将无法写入


## Mysql Operator
[MySQL Operator]((https://github.com/mysql/mysql-operator))是一个开源项目，用于在Kubernetes上管理MySQL数据库。它通过CRD扩展Kubernetes API，支持数据库实例、用户和备份的创建与管理。
Mysql Operator基于 MySQL InnoDB Cluster 模式部署Mysql集群。 

特点：
- 使用 CRD 定义Mysql Cluster
- 自动部署和用户创建
- 支持自动定时备份到本地磁盘或者S3等存储

从介绍上看，基本上`Mysql`高可用的能力基本上都照顾到了，基于`Mysql-Operator`可以快速搭建一套高可用的数据库。当然从实际使用体验上来看，还是会有一些细节问题`Mysql-Operator`并没有处理到位（当然也许是使用姿势问题）
- 动态调整 `Router` 数量并没有立即生效
- 删除已创建实例有时候会卡主无法正常完成
- 没有集成监控能力，需要自己部署 `mysqld-exporter` 以及 `ServiceMonitor`等资源


# 安装

## 安装 Mysql-Operator
通过下面的命令安装
```shell
# 安装CRD和operator
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.1.0-2.2.2/deploy/deploy-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.1.0-2.2.2/deploy/deploy-operator.yaml
```

安装成功后
```shell
kubectl get pods --namespace mysql-operator
NAME                                READY   STATUS    RESTARTS   AGE
mysql-operator-6b7947fb87-kk59z     1/1     Running   0          16h
```

## 创建数据库
参考测试数据库资源文件[mycluster.yaml](/k8s/mysql/mycluster.yaml)，创建数据库。
```shell
kubectl apply --namespace mysql-operator -f ./k8s/mysql/mycluster.yaml
```

数据创建成功后，namespace(`mysql-operator`)会新增以下资源
| type | name | 介绍 |
| - | - | - |
| StatefulSet | mycluster | mysql服务实例，（示例配置中有3实例，所以对应有3个Pod） |
| Deployment | mycluster-router | mysql服务代理，（示例配置中有2实例，所以对应有2个Pod） |
| Service | mycluster | mysql服务Service，通过它访问Mysql集群 |
| PVC | datadir-mycluster-* | 分别对应3个Mysql实例的PVC（自动绑定到创建的3个PV） |
| Secret | mycluster-* | 分别对应自动创建的几个mysql账号密码 |

## 数据库备份
### 自动定时备份
`Mysql-Operator` 自带了数据备份的能力，只需要在 `InnoDBCluster` 中配置备份规则即可。
参考[示例配置文件](/k8s/mysql/mycluster.yaml)，备份参数的一些介绍如下：
- spec.backupProfiles.name: 备份配置的名称
- spec.backupProfiles.dumpInstance.storage.s3: 备份存储的目标位置，这里使用了`S3`，也可以备份到本地磁盘等其他位置，具体参考[storage](https://dev.mysql.com/doc/mysql-operator/en/mysql-operator-properties.html#mysql-operator-spec-innodbclusterspecbackupprofilesindexdumpinstancestorage)
- backupSchedules.schedule: 自动备份的定时设置，参考`Crontab`的时间配置即可
- backupSchedules.enable: 设置为false,可以临时关闭

> PS：
> 1. 请确保示例配置`minio-mysql-backup-secret`中的`accesskey/secret`配置正确
> 2. 自动备份文件会不停的产生文件，所以`minio`的bucket最好设置一下自动清理机制（比如只保留最近30天的备份）。

### 手动备份
通过CRD`MySQLBackup`，可以手动执行一次备份任务，使用比较简单，直接参考[backup.yaml](/k8s/mysql/backup-once.yaml) 创建一个CRD即可。备份成功后，对应的状态会显示`Completed`。
```bash
#kubectl get mysqlbackup -A
NAMESPACE        NAME                    CLUSTER     STATUS      OUTPUT                                  AGE
mysql-operator   a-cool-one-off-backup   mycluster   Completed   a-cool-one-off-backup-20241124-061808   2m56s
```
对应的`MinIO` Bucket中也将会显示备份的文件
```
root@curl-test-f448f74cc-fn8n8:/app# mc ls myminio/mysql-backup/mycluster/a-cool-one-off-backup-20241124-061808/ | head
[2024-11-24 06:18:14 UTC] 1.1KiB STANDARD @.done.json
[2024-11-24 06:18:13 UTC] 1.5KiB STANDARD @.json
[2024-11-24 06:18:13 UTC]   295B STANDARD @.post.sql
[2024-11-24 06:18:13 UTC]   295B STANDARD @.sql
[2024-11-24 06:18:13 UTC] 8.9KiB STANDARD @.users.sql
[2024-11-24 06:18:13 UTC] 2.7KiB STANDARD mysql_innodb_cluster_metadata.json
[2024-11-24 06:18:13 UTC]  21KiB STANDARD mysql_innodb_cluster_metadata.sql
```


## Mysql InnoDB Cluster监控
Mysql 实例的监控，可以使用开源项目 [mysqld_exporter](https://github.com/prometheus/mysqld_exporter)； 

### 1. 创建`Mysql`账密
```sql
CREATE USER 'exporter'@'%' IDENTIFIED BY '<exporter-passwd>' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
```

### 2. 部署`mysqld_exporter`
示例部署文件参考 [mysqld-exporter.yaml](/k8s/mysql/exporter.yaml)
```shell
kubectl apply -f ./k8s/mysql/exporter.yaml
```

> PS:
> - 注意 `mysql-exporter.yaml` 中 `my.cnf` 账密和第一步账密一致
> - 如果需要部署其他namespace请调整yaml文件，默认部署到 `mysql-operator`

### 3. 通过 `PodMonitor`
参考配置文件 [mysql-pod-monitor.yaml](/k8s/mysql/pod-monitor.yaml) 创建Mysql实例的Metrics采集。
```shell
kubectl apply -f ./k8s/mysql/pod-monitor.yaml
```

其中关键的几个字段介绍:
| 字段 | 意义 |
| - | - | 
| spec.selector.matchLabels."aproton.tech/mysql-component" | 选择指定`Label`的Pod监控，需要和`InnoDBCluster`中的`Label`保持一致，建议`InnoDBCluster`统一使用示例中的`Label`，这样`PodMonitor`只需要部署一次即可 |
| spec.endpoints[0].relabelings[2].replacement | `mysqld_exporter` 的服务名，和第2步部署的 `Service` 保持一致 |

> PS: 这里使用 `PodMonitor` 而不是 `ServiceMonitor` 是因为 `Mysql-Operator` 默认创建了两个 `Service`， 分别用于 `mysql-service` 和 `mysql-router`，但是无法通过 `Label` 来区分两者，所以使用了 `PodMonitor` 直接采集Pod。

### 4. `Grafana` 监控大盘
`Grafana` 配置Dashboard, ID: `17320`

# 附录
- [手把手教会你快速部署 MySQL 8.0 InnoDB Cluster](http://47.116.124.235/article/mysql-cluster-in-docker-compose)
- [k8s使用operator部署Mysql InnoDB Cluster](https://blog.csdn.net/weixin_46510209/article/details/131782499)
- [MGR介绍/优化最佳实践等](https://www.yunweidashu.com/doc/45/)
- [Mysql 5.7升级到Mysql 8.0兼容性问题](https://blog.bitipcman.com/rds-mysql-57-to-8-major-version-upgrade/)
- [Mysql operator S3 innodbcluster backup SECRET CONFIG](https://sysrestarting.blogspot.com/2024/06/mysql-operator-s3-innodbcluster-backup.html)
- [K8s 监控Mysql](https://blog.csdn.net/qq_39287495/article/details/140384007)
- [ServiceMonitor](https://docs.openshift.com/container-platform/4.10/rest_api/monitoring_apis/servicemonitor-monitoring-coreos-com-v1.html)