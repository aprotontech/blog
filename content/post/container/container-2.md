---
title: "Container研究 - 从头实现系列之二（镜像管理）"
date: 2024-11-18T19:23:16+08:00
draft: false
categories:
  - DevOps
tags:
  - Container
---

# 镜像格式
## 镜像格式历史
我们通过一张表格快速浏览一下镜像格式的历史

| 时间 | 版本 | Manifest Type | 简介 |
| - | - | - | - |
| 2013 | Docker Image V1 | | `Docker`镜像版本1,2017年已被启用 |
| 2016 | Docker Image Manifest V2 Schema 1 | `application/vnd.docker.distribution.manifest.v1+json` | 过度格式,目前也已弃用 |
| 2017 | Docker Image Manifest V2 Schema 2 | `application/vnd.docker.distribution.manifest.v2+json` | 支持多架构镜像 |
| 2017 | OCI Image | `application/vnd.oci.image.manifest.v1+json` | `Docker`将`Docker Image Manifest V2 Schema 2`捐赠给`OCI`之后发展的镜像格式 |

- 目前主要使用的是`Docker Image Manifest V2 Schema 2`, `OCI Image`两种格式
- 因为`OCI Image`基于`Docker Image Manifest V2 Schema 2`，改动也不太大，所以一般来说`OCI Image`会兼容`Docker Image Manifest V2 Schema 2`

## OCI Image格式
下面我们基于`OCI Image`来介绍一下镜像格式，以镜像`docker.io/library/nginx:latest`为示例，首先将镜像导出为`tar`文件:
```bash
# 需要使用OCI格式保存，不指定的话保存的是`docker`格式
docker save --format oci-archive -o nginx.latest.tar docker.io/library/nginx:latest
tar xf nginx.latest.tar
tree .
```

<details>
<summary>镜像的文件列表，以及核心文件</summary>

```plain
.
├── blobs
│   └── sha256
│       ├── 1cc44349830956f9cc802fbc1eec9c21607734c9ca73bc0ae5c7c21d9a5db496
│       ├── 24756d56029d99753a42def05d33b40f6e4ae339da299c800c096afd9fe21b93
│       ├── 3b25b682ea82b2db3cc4fd48db818be788ee3f902ac7378090cf2624ec2442df
│       ├── 3d88ef2a9bb1959b3532c0248823c8f7fe6d15778366abfce353bf718b57d6e0
│       ├── 59c6c2d6ea42254ecad4e9cd70da749b4bea71718e6fc1cd8aedce3df545cc03
│       ├── 6124ee8476f2fb1f4fed1d8a5c1cec7b996edec4a795b666508ab4f11e3d5ce7
│       ├── 8e3c33bfd178b996bed2df61c70102d8683f5ecf16dd768b21fe4cceee15f3c3
│       ├── bcbeed608da55946855988b2c1d73ef30ebe471aa6c1096d5817cb030982f61b
│       └── c694f2db45b5716780d0b49b476830f3d3aec7ffc7981e9c33ef03b9118f702e
├── index.json
└── oci-layout

2 directories, 11 files
```


```json
# index.json
# 根据 `manifests[0].digest` 索引文件 `blobs/sha256/24756d56...`
{
  "schemaVersion": 2,
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:24756d56029d99753a42def05d33b40f6e4ae339da299c800c096afd9fe21b93",
      "size": 1904,
      "annotations": {
        "org.opencontainers.image.ref.name": "docker.io/library/nginx:latest"
      }
    }
  ]
}
```

```json
# blobs/sha256/24756d56029d99753a42def05d33b40f6e4ae339da299c800c096afd9fe21b93
# 根据 `config.digest` 索引文件 `blobs/sha256/3b25b682...`
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:3b25b682ea82b2db3cc4fd48db818be788ee3f902ac7378090cf2624ec2442df",
    "size": 8714
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:59c6c2d6ea42254ecad4e9cd70da749b4bea71718e6fc1cd8aedce3df545cc03",
      "size": 30217611
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:6124ee8476f2fb1f4fed1d8a5c1cec7b996edec4a795b666508ab4f11e3d5ce7",
      "size": 45378600
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:c694f2db45b5716780d0b49b476830f3d3aec7ffc7981e9c33ef03b9118f702e",
      "size": 638
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:3d88ef2a9bb1959b3532c0248823c8f7fe6d15778366abfce353bf718b57d6e0",
      "size": 972
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:8e3c33bfd178b996bed2df61c70102d8683f5ecf16dd768b21fe4cceee15f3c3",
      "size": 412
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:1cc44349830956f9cc802fbc1eec9c21607734c9ca73bc0ae5c7c21d9a5db496",
      "size": 1235
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:bcbeed608da55946855988b2c1d73ef30ebe471aa6c1096d5817cb030982f61b",
      "size": 1443
    }
  ],
  "annotations": {
    "com.docker.official-images.bashbrew.arch": "amd64",
    "org.opencontainers.image.base.digest": "sha256:d83056144b2dd301730d2739635c8cbdeaaae20d6887146434184f8c060f03ce",
    "org.opencontainers.image.base.name": "debian:bookworm-slim",
    "org.opencontainers.image.created": "2024-10-02T17:55:35Z",
    "org.opencontainers.image.revision": "6a4c0cb4ac7e53bbbe473df71b61a5bf9f95252f",
    "org.opencontainers.image.source": "https://github.com/nginxinc/docker-nginx.git#6a4c0cb4ac7e53bbbe473df71b61a5bf9f95252f:mainline/debian",
    "org.opencontainers.image.url": "https://hub.docker.com/_/nginx",
    "org.opencontainers.image.version": "1.27.2"
  }
}
```

```json
# blobs/sha256/3b25b682ea82b2db3cc4fd48db818be788ee3f902ac7378090cf2624ec2442df
{
  "architecture": "amd64",
  "config": {
    "ExposedPorts": {
      "80/tcp": {}
    },
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "NGINX_VERSION=1.27.2",
      "NJS_VERSION=0.8.6",
      "NJS_RELEASE=1~bookworm",
      "PKG_RELEASE=1~bookworm",
      "DYNPKG_RELEASE=1~bookworm"
    ],
    "Entrypoint": [
      "/docker-entrypoint.sh"
    ],
    "Cmd": [
      "nginx",
      "-g",
      "daemon off;"
    ],
    "Labels": {
      "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>"
    },
    "StopSignal": "SIGQUIT",
    "ArgsEscaped": true
  },
  "created": "2024-10-02T17:55:35Z",
  "history": [
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "/bin/sh -c #(nop) ADD file:90b9dd8f12120e8b2cd3ece45fcbe8af67e40565e2032a40f64bd921c43e2ce7 in / "
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "/bin/sh -c #(nop)  CMD [\"bash\"]",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "LABEL maintainer=NGINX Docker Maintainers <docker-maint@nginx.com>",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENV NGINX_VERSION=1.27.2",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENV NJS_VERSION=0.8.6",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENV NJS_RELEASE=1~bookworm",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENV PKG_RELEASE=1~bookworm",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENV DYNPKG_RELEASE=1~bookworm",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "RUN /bin/sh -c set -x     && groupadd --system --gid 101 nginx     && useradd --system --gid nginx --no-create-home --home /nonexistent --comment \"nginx user\" --shell /bin/false --uid 101 nginx     && apt-get update     && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates     &&     NGINX_GPGKEYS=\"573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 8540A6F18833A80E9C1653A42FD21310B49F6B46 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3\";     NGINX_GPGKEY_PATH=/etc/apt/keyrings/nginx-archive-keyring.gpg;     export GNUPGHOME=\"$(mktemp -d)\";     found='';     for NGINX_GPGKEY in $NGINX_GPGKEYS; do     for server in         hkp://keyserver.ubuntu.com:80         pgp.mit.edu     ; do         echo \"Fetching GPG key $NGINX_GPGKEY from $server\";         gpg1 --keyserver \"$server\" --keyserver-options timeout=10 --recv-keys \"$NGINX_GPGKEY\" && found=yes && break;     done;     test -z \"$found\" && echo >&2 \"error: failed to fetch GPG key $NGINX_GPGKEY\" && exit 1;     done;     gpg1 --export \"$NGINX_GPGKEYS\" > \"$NGINX_GPGKEY_PATH\" ;     rm -rf \"$GNUPGHOME\";     apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/*     && dpkgArch=\"$(dpkg --print-architecture)\"     && nginxPackages=\"         nginx=${NGINX_VERSION}-${PKG_RELEASE}         nginx-module-xslt=${NGINX_VERSION}-${DYNPKG_RELEASE}         nginx-module-geoip=${NGINX_VERSION}-${DYNPKG_RELEASE}         nginx-module-image-filter=${NGINX_VERSION}-${DYNPKG_RELEASE}         nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${NJS_RELEASE}     \"     && case \"$dpkgArch\" in         amd64|arm64)             echo \"deb [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/mainline/debian/ bookworm nginx\" >> /etc/apt/sources.list.d/nginx.list             && apt-get update             ;;         *)             tempDir=\"$(mktemp -d)\"             && chmod 777 \"$tempDir\"                         && savedAptMark=\"$(apt-mark showmanual)\"                         && apt-get update             && apt-get install --no-install-recommends --no-install-suggests -y                 curl                 devscripts                 equivs                 git                 libxml2-utils                 lsb-release                 xsltproc             && (                 cd \"$tempDir\"                 && REVISION=\"${NGINX_VERSION}-${PKG_RELEASE}\"                 && REVISION=${REVISION%~*}                 && curl -f -L -O https://github.com/nginx/pkg-oss/archive/${REVISION}.tar.gz                 && PKGOSSCHECKSUM=\"6982e2df739645fc72db5bdf994032f799718230e7016e811d9d482e5cf41814c888660ca9a68814d5e99ab571e892ada3bd43166e720cbf04c7f85b6934772c *${REVISION}.tar.gz\"                 && if [ \"$(openssl sha512 -r ${REVISION}.tar.gz)\" = \"$PKGOSSCHECKSUM\" ]; then                     echo \"pkg-oss tarball checksum verification succeeded!\";                 else                     echo \"pkg-oss tarball checksum verification failed!\";                     exit 1;                 fi                 && tar xzvf ${REVISION}.tar.gz                 && cd pkg-oss-${REVISION}                 && cd debian                 && for target in base module-geoip module-image-filter module-njs module-xslt; do                     make rules-$target;                     mk-build-deps --install --tool=\"apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes\"                         debuild-$target/nginx-$NGINX_VERSION/debian/control;                 done                 && make base module-geoip module-image-filter module-njs module-xslt             )                         && apt-mark showmanual | xargs apt-mark auto > /dev/null             && { [ -z \"$savedAptMark\" ] || apt-mark manual $savedAptMark; }                         && ls -lAFh \"$tempDir\"             && ( cd \"$tempDir\" && dpkg-scanpackages . > Packages )             && grep '^Package: ' \"$tempDir/Packages\"
  && echo \"deb [ trusted=yes ] file://$tempDir ./\" > /etc/apt/sources.list.d/temp.list             && apt-get -o Acquire::GzipIndexes=false update             ;;     esac         && apt-get install --no-install-recommends --no-install-suggests -y                         $nginxPackages                         gettext-base                         curl     && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list         && if [ -n \"$tempDir\" ]; then         apt-get purge -y --auto-remove         && rm -rf \"$tempDir\" /etc/apt/sources.list.d/temp.list;     fi     && ln -sf /dev/stdout /var/log/nginx/access.log     && ln -sf /dev/stderr /var/log/nginx/error.log     && mkdir /docker-entrypoint.d # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "COPY docker-entrypoint.sh / # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "COPY 15-local-resolvers.envsh /docker-entrypoint.d # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "COPY 20-envsubst-on-templates.sh /docker-entrypoint.d # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "COPY 30-tune-worker-processes.sh /docker-entrypoint.d # buildkit",
      "comment": "buildkit.dockerfile.v0"
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "ENTRYPOINT [\"/docker-entrypoint.sh\"]",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "EXPOSE map[80/tcp:{}]",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "STOPSIGNAL SIGQUIT",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    },
    {
      "created": "2024-10-02T17:55:35Z",
      "created_by": "CMD [\"nginx\" \"-g\" \"daemon off;\"]",
      "comment": "buildkit.dockerfile.v0",
      "empty_layer": true
    }
  ],
  "os": "linux",
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:98b5f35ea9d3eca6ed1881b5fe5d1e02024e1450822879e4c13bb48c9386d0ad",
      "sha256:b33db0c3c3a85f397c49b1bf862e0472bb39388bd7102c743660c9a22a124597",
      "sha256:63d7ce983cd5c7593c2e2467d6d998bb78ddbc2f98ec5fed7f62d730a7b05a0c",
      "sha256:296af1bd28443744e7092db4d896e9fda5fc63685ce2fcd4e9377d349dd99cc2",
      "sha256:8ce189049cb55c3084f8d48f513a7a6879d668d9e5bd2d4446e3e7ef39ffee60",
      "sha256:6ac729401225c94b52d2714419ebdb0b802d25a838d87498b47f6c5d1ce05963",
      "sha256:e4e9e9ad93c28c67ad8b77938a1d7b49278edb000c5c26c87da1e8a4495862ad"
    ]
  }
}
```

</details>

核心的几个文件如下:
| 文件 | 简介 |
| -- | -- |
| oci-layout | 版本信息 |
| index.json | `清单`描述文件; 其中`org.opencontainers.image.ref.name`对应镜像`Tag`,`digest`指向镜像的描述信息文件名(`Hash`) |
| blobs/sha256 | 镜像的内容，可能是：文件压缩包，或者`Json`格式的描述文件 |
| blobs/sha256/24756d56... | `JSON`格式,镜像实际的描述信息,包含镜像每一层的文件名(`Hash`),以及镜像`Dockerfile`的信息文件名(`Hash`) |
| blobs/sha256/3b25b682... | `JSON`格式,`Dockerfile`的信息（`Dockerfile`指令,环境变量,命令行参数等） |

# 镜像管理
通过上述的分析，`OCI Image`格式还是比较清晰的，直接手写一个解析函数也不是很复杂，但是在这里镜像本身并不是核心重点，所以还是使用开源库比较好。

[`go-containerregistry`](https://github.com/google/go-containerregistry) 是一个`golang`的镜像库，通过它可以直接管理镜像；且给的示例代码也比较多，基本上参考(`COPY`)就可以拿过来用了。

`go-containerregistry`在本地维护一个镜像仓库（目录），内容和上文中的`nginx`镜像解压后是一样的，当然这个仓库里面可以有很多的镜像；
所以`index.json`文件中`manifests`数组会包含多个`item`。

## 镜像拉取
完整的代码参考: [image/pull.go](https://github.com/aprotontech/container/blob/main/image/pull.go)；下面只摘取核心的代码进行介绍。

`pull`的命令定义
```golang
func ImageCommand() *cobra.Command {
	cmd.AddCommand(&cobra.Command{
		Use:   "pull [OPTIONS] NAME[:TAG|@DIGEST]",
		Short: "pull image",
		Args:  cobra.ExactArgs(1),
		Run:   PullImageCommand,
	})
}
```

借助与`go-containerregistry`, 拉取镜像非常简单，伪代码如下：
```golang
func PullImageCommand(cmd *cobra.Command, args []string) {
  ref, err := name.ParseReference(args[0]) // args[0]是拉取镜像,这里是格式化一下镜像`tag`
  lp, err := layout.FromPath(RepositoryPath) // 定义 `repository`

  // 定义一些拉取的参数，比如系统，架构等
  remoteOptions := []remote.Option{
		remote.WithContext(ctx),
		remote.WithTransport(remote.DefaultTransport),

		remote.WithPlatform(v1.Platform{
			OS:           runtime.GOOS,
			Architecture: runtime.GOARCH,
		}),
	}

  // 执行实际的拉取
	rmt, err := remote.Get(ref, remoteOptions...)
  img, err = rmt.Image()
  // 保存镜像,更新`index.json`文件
  err = lp.ReplaceImage(img, match.Name(ref.Name()), layout.WithAnnotations(map[string]string{
		oci.AnnotationRefName: ref.Name(),
	}))
}
```

整个核心代码非常简洁，复杂的操作都被`go-containerregistry`封装好了，直接调用即可。  
不过`pull`的镜像可能是多架构镜像，所以有2种选择：
- 直接在本地镜像仓库中保存多架构镜像
- 根据本地系统,架构选择最合适的镜像保存，其他的镜像直接忽略。  
  代码中选择了这种方法，具体可以参考[image/pull.go](https://github.com/aprotontech/container/blob/main/image/pull.go#L55)


## 镜像列表
镜像列表的操作非常简单，实际上就是提取`index.json`中的`manifests`列表，将其中的镜像名罗列出来即可。
当然这里仍然使用`go-containerregistry`库来减少文件的解析工作。

```golang
func ListImageCommand(cmd *cobra.Command, args []string) {
	lp, err := layout.FromPath(RepositoryPath)
	utils.Assert(err)

  // 解析 `index.json`文件
	ii, err := lp.ImageIndex()
	utils.Assert(err)

	imf, err := ii.IndexManifest()
	utils.Assert(err)

  // 定义打印的表格头: REPOSITORY, TAG, IMAGE ID, SIZE
	table := newImageListTableRender()
	for _, img := range imf.Manifests {
    // 每个镜像插入一行
		if row, err := newImageListRow(ii, &img); err == nil {
			table.Append(row)
		}
	}
	table.Render()
}
```

需要注意的是:
- 镜像的`SIZE`是所有`layer`层的大小总和，所以需要根据镜像的`manifest.digest`拿到镜像描述文件，统计大小。


## 其他操作
镜像的`save/load/remove/tag`等操作，基本上同上面一样，使用`go-containerregistry`库后非常简单，这里就不赘述了。

可以参考代码： [image](https://github.com/aprotontech/container/tree/main/image)


# 演示效果
(待补充)

# 附录
- [K8S 1.20 弃用 Docker 评估之：Docker 和 OCI 镜像格式的差别](https://cloud.tencent.com/developer/article/1985774)
- [揭秘容器(三)：容器镜像](https://panzhongxian.cn/cn/2023/11/demystifying-containers-part-iii-container-images/)