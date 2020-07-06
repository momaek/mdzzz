---
title: 如何用GitHub Actions编译Golang项目
date: 2019-03-08 11:29:48
tags: 
    - Golang
    - Github Actions
photos:
    - https://github.githubassets.com/images/modules/site/social-cards/actions.png
---

[Github Actions](https://github.com/features/actions) 是 Github 在 2018 年年末的时候推出的新平台，旨在成为通用的工作流程自动化工具。事实上，Github 是一家致力于改进开发者协作工具的公司，这一举措让它扩展到了 CI/CD 领域，em~~ interesting….

<!-- more -->

### 0x00 Overview

在我们探究 Actions 和 Workflow 之前，让我们先来看下这个东西存在的意义是什么。要为一个 repo 做任何的一些自动化操作，例如跑测试或者编译(包，二进制文件等)，你需要依赖一个外部的服务或者自己通过 Github webhooks 来做这些事情。现在有了 Github Actions 后，你可以不需要借助第三方工具来处理这些事情了。 Github Actions 是通过 Docker 来做这些事情的，也就是说你可以用公共的 Docker 镜像。

再多说一句，目前(2019.03.08) Github Actions 是需要排队申请公测的，所以有需要的童鞋去排队吧。



### 0x01 Workflow Setup

首先我们先来看一下，我这边项目的结构：

```
├── LICENSE
├── README.md
├── env.sh
├── src
│   └── app
│       └── main.go
└── workflow
    ├── build
    │   ├── Dockerfile
    │   └── entrypoint.sh
    └── deploy
        ├── Dockerfile
        └── entrypoint.sh
```

这应该是一个比较典型的项目结构，项目里面自带一个 `GOPATH`。

我们心间一个目录：`.github`，然后在新目录里面建一个文件 `main.workflow`。`main.workflow` 的内容如下：

```
workflow "Build Project" {
  on = "push" // 当你把你本地的代码 push 到 GitHub 的时候，就会触发这个工作流
  resolves = ["build"]  // 需要执行的 actions 放在 resolves 里面，如果有多个，可以用 ',' 分割。 当有多个的时候，它们是并行执行的
}

action "build" {
  uses = "./actions/build"
  args = "linux/amd64 darwin/amd64"
}
```

可以看到这个里面有 3 大块的内容，我们来简单讲解一下。

- workflow 一个 `workflow` 文件可以包含多个 `workflow` 模块，每个模块都有一个唯一的名称和两个属性`on` 和 `resolves`，属性的具体作用可以看 [官方文档](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#workflow-attributes)
- action 一个 `workflow` 文件可以包含至多100个 `action` 模块，每个模块都有一个唯一的名称，模块里面的 `uses` 属性是必须的，属性的具体作用可以看 [官方文档](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#actions-attributes)



### 0x10 Action Script

我们可以看到 `action` 模块里面有一个 `uses` 的必选项，这个就是用来指定你的 Docker 容器的。支持的方式有很多种，具体可以参考[这里](https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#using-a-dockerfile-image-in-an-action)，我们这里用的是 `./path/to/dir` 的这种方式，因为 `workflow` 和代码在相同的 repo 里面。

接下来来看看，我们 `./workflow/build/Dockerfile` 的内容：

```
FROM golang:1.11

RUN \
  apt-get update && \
  apt-get install -y ca-certificates openssl zip && \
  update-ca-certificates && \
  rm -rf /var/lib/apt

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"] // 在 workflow 文件的 action 模块里面，如果没有 runs 属性，那么就会用这个 ENTRIYPOINT，如果有那就使用 runs.
```

最后我们来看看 `./workflow/build/entrypoint.sh` 的内容：

```
#!/bin/bash

set -e

if [[ -z "$GITHUB_WORKSPACE" ]]; then
  echo "Set the GITHUB_WORKSPACE env variable."
  exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

# GITHUB_WORKSPACE 和 GITHUB_REPOSITORY 是 workflow 内置的环境变量
root_path="$GITHUB_WORKSPACE"
release_path="$GITHUB_WORKSPACE/.release"
repo_name="$(echo $GITHUB_REPOSITORY | cut -d '/' -f2)"
targets=${@-"linux/amd64 linux/386 windows/amd64 windows/386"}

echo "----> Setting up Go repository"
mkdir -p $release_path

cd $root_path/Server
source env.sh
cd src/app

for target in $targets; do
  os="$(echo $target | cut -d '/' -f1)"
  arch="$(echo $target | cut -d '/' -f2)"
  output="${release_path}/${repo_name}_${os}_${arch}"

  echo "----> Building project for: $target"
  GOOS=$os GOARCH=$arch CGO_ENABLED=0 go build -o $output
  zip -j $output.zip $output > /dev/null
done

echo "----> Build is complete. List of files at $release_path:"
cd $release_path
ls -al
```

这里需要注意的一点是你需要 `chmod +x entrypoint.sh` 给 `entrypoint.sh` 这个文件执行权限，否则 workflow 在运行的时候会报错。

这样，当你在 `push` 到 GitHub 的时候，就会触发 workflow。运行的日志大致如下：

```
### STARTED build 09:48:13Z

Pulling image: gcr.io/github-actions-images/action-runner:latest
latest: Pulling from github-actions-images/action-runner
169185f82c45: Pulling fs layer
0ccde4b6b241: Pulling fs layer
d0372f57daa2: Pulling fs layer
165911d108d6: Pulling fs layer
54996bce1de5: Pulling fs layer
165911d108d6: Waiting
54996bce1de5: Waiting
0ccde4b6b241: Verifying Checksum
0ccde4b6b241: Download complete
d0372f57daa2: Verifying Checksum
d0372f57daa2: Download complete
169185f82c45: Verifying Checksum
169185f82c45: Download complete
54996bce1de5: Verifying Checksum
54996bce1de5: Download complete
165911d108d6: Verifying Checksum
165911d108d6: Download complete
169185f82c45: Pull complete
0ccde4b6b241: Pull complete
d0372f57daa2: Pull complete
165911d108d6: Pull complete
54996bce1de5: Pull complete
Digest: sha256:c9bb432ec5ec08ee08b040a9fccacebbbf8a91444dac4721600cf5dca9dae57e
Status: Downloaded newer image for gcr.io/github-actions-images/action-runner:latest
fc613b4dfd6736a7bd268c8a0e74ed0d1c04a959f59dd74ef2874983fd443fc9: Pulling from gct-12-3hn-cry55j2e8o-ikyqx-80/dabb005a903a36aae14c496f0250249d66465edce31277b5b1609d939a40e877/5c3174b74edc6f2b9e0743594b8bd3c7f31e4f4405758cc9872b3fe1de1d28b4
22dbe790f715: Already exists
0250231711a0: Already exists
6fba9447437b: Already exists
c2b4d327b352: Already exists
619f4932b7ea: Already exists
e2fd6cbd3c6f: Pulling fs layer
1d96446d2b20: Pulling fs layer
6c3860f2355d: Pulling fs layer
b9beb9e9e7b4: Pulling fs layer
b9beb9e9e7b4: Waiting
1d96446d2b20: Verifying Checksum
1d96446d2b20: Download complete
6c3860f2355d: Verifying Checksum
6c3860f2355d: Download complete
b9beb9e9e7b4: Verifying Checksum
b9beb9e9e7b4: Download complete
e2fd6cbd3c6f: Verifying Checksum
e2fd6cbd3c6f: Download complete
e2fd6cbd3c6f: Pull complete
1d96446d2b20: Pull complete
6c3860f2355d: Pull complete
b9beb9e9e7b4: Pull complete
Digest: sha256:f4f24205b3442b3dae915837f7f8823e6801382edfff9d581f4142723221ca2b
Status: Downloaded newer image for gcr.io/gct-12-3hn-cry55j2e8o-ikyqx-80/dabb005a903a36aae14c496f0250249d66465edce31277b5b1609d939a40e877/5c3174b74edc6f2b9e0743594b8bd3c7f31e4f4405758cc9872b3fe1de1d28b4:fc613b4dfd6736a7bd268c8a0e74ed0d1c04a959f59dd74ef2874983fd443fc9
Step 1/4 : FROM golang:1.11
1.11: Pulling from library/golang
22dbe790f715: Already exists
0250231711a0: Already exists
6fba9447437b: Already exists
c2b4d327b352: Already exists
619f4932b7ea: Already exists
e2fd6cbd3c6f: Already exists
1d96446d2b20: Already exists
Digest: sha256:1a0252130e79773cbda16c451b125cbf18d59fe3e682d344676a5103bfcaedcc
Status: Downloaded newer image for golang:1.11
 ---> 1454e2b3d01f
Step 2/4 : RUN   apt-get update &&   apt-get install -y ca-certificates openssl zip &&   update-ca-certificates &&   rm -rf /var/lib/apt
 ---> Using cache
 ---> 56bef95c0fd8
Step 3/4 : COPY entrypoint.sh /entrypoint.sh
 ---> Using cache
 ---> b9053ad11b60
Step 4/4 : ENTRYPOINT ["/entrypoint.sh"]
 ---> Using cache
 ---> 8e7345aa7948
Successfully built 8e7345aa7948
Successfully tagged gcr.io/gct-12-3hn-cry55j2e8o-ikyqx-80/dabb005a903a36aae14c496f0250249d66465edce31277b5b1609d939a40e877/5c3174b74edc6f2b9e0743594b8bd3c7f31e4f4405758cc9872b3fe1de1d28b4:fc613b4dfd6736a7bd268c8a0e74ed0d1c04a959f59dd74ef2874983fd443fc9
Already have image (with digest): gcr.io/github-actions-images/action-runner:latest
----> Setting up Go repository
----> Building project for: linux/amd64
----> Building project for: darwin/amd64
----> Build is complete. List of files at /github/workspace/.release:
total 62360
drwxr-xr-x  2 root root     4096 Mar  8 09:50 .
drwxr-xr-x 12 root root     4096 Mar  8 09:48 ..
-rwxr-xr-x  1 root root 22096424 Mar  8 09:50 app_darwin_amd64
-rw-r--r--  1 root root  9822499 Mar  8 09:50 app_darwin_amd64.zip
-rwxr-xr-x  1 root root 22118946 Mar  8 09:49 app_linux_amd64
-rw-r--r--  1 root root  9801034 Mar  8 09:49 app_linux_amd64.zip

### SUCCEEDED build 09:50:06Z (1m52.781s)
```

### 0x11 Deploy 

编译好的文件存在了 `$GITHUB_WORKSPACE/.release` 这个地方，所以只需要在创建一个 `deploy ` 的 action 就可以拿到编译好的文件去部署了。

![](https://oa7ktymto.qnssl.com/workflow.png)



最后，项目的地址 [https://github.com/momaek/mdxz](https://github.com/momaek/mdxz)