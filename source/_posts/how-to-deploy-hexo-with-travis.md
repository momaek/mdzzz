---
title: 如何用 Travis 部署 Hexo
date: 2016-10-18 00:55:19
tags:
	- Hexo
photos:
	- https://oa7ktymto.qnssl.com/hexo.png
---
简单介绍一下如何用Travis来部署Hexo的博客到服务器上面
<!--more-->

### 0x001

我们先来欣赏一下新海诚的最新作《你的名字》的ED。

<iframe frameborder="no" border="0" marginwidth="0" marginheight="0" width=298 height=52 src="//music.163.com/outchain/player?type=2&id=426881506&auto=1&height=32"></iframe>

希望各位看官喜欢。

### 0x010

之前自己在折腾博客的前端。 以前是用 `Angular1` 写的前端，博客的所有文章全部存七牛，用`Go`写了一个脚本来处理本地的文章同步到七牛的问题。

这种方式存在的几个问题：
第一，不方便做归档。
第二，不方便开放评论。
第三，不方便做SEO(可能是我太菜了。。逃)。

所以就想到直接用现有的博客框架来直接搭了一个。

### 0x100

看了下 [hexo](https://hexo.io) 的官网，感觉很简单的。按照官方的 _quickstart_ 很快就在本地的 4000 端口把博客搭起来了。 神速啊～～～

大概试用了一下，感觉还不错。 顺便就换了一个主题 [Daily](https://https://github.com/GallenHu/hexo-theme-Daily)。 然后把原来博客上面的仅有的一篇文章直接 Copy 下来：
```
hexo new XXXXX
hexo serve
```
感觉效果还不错，看起来简洁了很多。接下来就是如何部署到VPS上面去了。

### 0x011

首先想到的是把本地的 blog 直接推到 Github，然后在 VPS 上面装 Github, NodeJs, Hexo, Nginx 等等一系列的工具把本地的代码在 VPS 上面再编译一次。啊啊，好麻烦，还不如用七牛。

查了一下 hexo 的文档，发现它可以把博客 generate 成一对静态文件，这个功能简直太棒了。这样的话就可以直接用 nginx 来代理一下静态文件就可以了。

### 0x100

（不是很爽的操作方式）首先创建一个 Github 的 repo， 然后在本地的 blog 文件夹执行：
```
git init
git remote add origin git@github.com:{{YourName}}/{{YourRepoName}}.git
```
此时如果你在远端新建了 `develop` 分支作为默认分支的话。 那么你就准备接受被坑爹吧，这个时候你把本地的代码 push 到远端的 `develop`，但是你不能把 	`develop` 分支的代码合并到 `master`。在你去比较这两个分支的时候会出这样的问题：
> There isn't anything to compare.
>
> master and develop are entirely different commit histories.

具体原因这个地方不展开。解决办法： 
```
git fetch origin 			// 在本地的 `develop` 分支
git rebase origin/master	// 把本地的 commit 历史修改掉
```
然后你在 `git push -f` 一次。现在你就可以 PR 到 `master` 分支了。

比较干净利落的操作方式：[Github](https://help.github.com/)

### 0x101 

用 Travis 部署到 VPS。很明显需要 Travis 有访问 VPS 的权限

接下来我们需要配置 travis-ci 了。
在本地下载一个 travis，推荐使用 `gem install travis`。 如果本地没有 `gem` 的童鞋可以 [Google](https://www.google.com.hk/webhp?sourceid=chrome-instant&ion=1&espv=2&ie=UTF-8#newwindow=1&safe=strict&q=ruby+gem++install) 一下如何安装。然后用 Github 账号登录到刚刚安装好的 travis 客户端。操作代码如下：
```
gem install travis
travis login // github username & password
```
-------------------------------------------

现在呢，我们需要为 Travis 生成一对公私钥，用来给 Travis 做登录用。
```
ssh-keygen -f travis 	// 一路回车下去，就会在当前文件夹内成两个文件
						
```
一个叫 travis(私钥) ，一个叫 travis.pub(公钥) 。把 travis.pub 的内容放到 VPS 用户目录的 `.ssh/authorized_keys` 里面。

现在移步到 blog 文件夹(放博客的地方)。新建一个 .travis 的文件夹，把刚刚创建的私钥移动到 .travis 这个文件夹下面。

然后
```
travis encrypt-file travis  --add

它会检测你当前所在的 repo ，需要你确认，输入 yes 就好
它会生成一个叫做 `travis.enc` 的文件在 .travis 下面
```

这个操作会在你当前的 repo 下面生成一个叫 `.travis.yml` 的文件，然后会在里面填上一些内容
```
before_install:
- openssl aes-256-cbc -K $encrypted_fda9e2a69cea_key -iv $encrypted_fda9e2a69cea_iv
  -in .travis/travis.enc -out ~/.ssh/id_rsa -d
- chmod 600 ~/.ssh/id_rsa

// 这个步骤可能出来有些童鞋不是这个样子的， 原因是路径不对。你修改一下 travis.enc 的路径就好啦。 后面会给出完整的命令行
```
然后在 `.travis.yml` 这个文件里面加上一些其他的东西就可以啦。 比如说我的
```
language: node_js
node_js:
- 6
branches:
  only:
  - master
install:
- npm install hexo-cli -g
- npm install
- npm install --save hexo-renderer-sass
addons:
  ssh_known_hosts: wxy.sexy:22
script:
- hexo clean
- hexo generate 
- rsync -az -vv --delete -e 'ssh -p 22' public/ [用户名]@[服务器]:[路径]
before_install:
- openssl aes-256-cbc -K $encrypted_fda9e2a69cea_key -iv $encrypted_fda9e2a69cea_iv
  -in .travis/travis.enc -out ~/.ssh/id_rsa -d
- chmod 600 ~/.ssh/id_rsa
```

### 0x110
这个是完整的命令：
假设：你的GithubId: hello, 你创建好的GithubRepo: world

```
// 初始化本地仓库
git clone git@github.com:hello@world.git

cd world

git checkout -b blog

// 安装 hexo
npm install hexo-cli -g
npm install

// 创建 .travis 文件夹
mkdir .travis
cd .travis

// 生成公私钥，然后把公钥放到 VPS 上
ssh-keygen -f travis

// 安装travis
// 如果没有 gem 的童鞋，请自行 Google
gem install travis

// 使用你的Github账号登录 travis
travis login 

cd ..

// 加密秘钥
travis encrypt-file .travis/travis  --add

// 把变更提交到远程仓库
git add .
git commit -m "init commit"
git push
```
这篇文章纯属扯淡。。
其实你可以不用 Travis 来部署。 你直接在本地
```
hexo g
scp public/ [name]@[ip]:[path] 
```
就好啦。用Travis还有安全问题。
就这样。
早睡，祝好

