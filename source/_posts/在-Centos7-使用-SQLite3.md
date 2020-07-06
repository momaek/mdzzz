---
title: 在 Centos7 使用 SQLite3 
date: 2020-05-30 16:15:05
tags: 
	- Golang
	- SQLite3
photos:
    - https://oa7ktymto.qnssl.com/golang-sqlite-simple-example.png
---

### 0x001 背景
打算在 Centos7 上跑 Golang 代码，Golang 里面用到 SQLite3 这个本地数据库，本来是想上 Mysql 的，但是想到 VPS 是 1核1G 就想直接用内嵌在应用里面的数据库，就想到了 SQLite3 ，直接一个 DB 文件就可以了，而且还可以直接用 Dropbox 同步，防止数据丢失，不是为一个好的选择。

### 0x010 第一次尝试
这里呢，我们用 `github.com/jinzhu/gorm` 这个 ORM 库来读写数据库，它已经自带了 SQLite3 的数据库驱动，所以直接上一段简单的代码：
```go
package main
import(
	"log"
	
	 "github.com/jinzhu/gorm"
	 _ "github.com/jinzhu/gorm/dialects/sqlite"
)

func main() {
	db, err := gorm.Open("sqlite3", "sqlite3.db")
	if err !=nil {
		log.Fatal(err)	
	}
	
	db.Automigrate(&Image{})
}

type Image struct{
	ID int `gorm:"primary_key"`
	Key string `gorm:"size:50"`
}
```
由于我本地是 Mac 环境，所以咱们直接交叉编译，然后把编译好的二进制文件扔到机器上执行就可以了。
```
➜ GOOS=linux GOARCH=amd64 go build -o bot main.go
➜ scp bot vps2:

这里我提前在我的 .ssh/config 里面加好了配置:
Host vps2
    User root
    Hostname **.**.**.*
    Port ***
    IdentityFile ~/.ssh/id_rsa
```

然后登录到机器上执行：
```
> ./bot 
2020/05/30 15:20:01 /Users/wentx/momaek/src/bot/main.go:59: Binary was compiled with 'CGO_ENABLED=0', go-sqlite3 requires cgo to work. This is a stub
```
噢，原来需要 CGO_ENABLED=1，那咱重新在本地编一个就可以了呗。
```
➜ GOOS=linux GOARCH=amd64 go build -o bot main.go
# github.com/mattn/go-sqlite3
sqlite3-binding.c:33723:42: error: use of undeclared identifier 'pread64'
sqlite3-binding.c:33741:42: error: use of undeclared identifier 'pwrite64'
sqlite3-binding.c:33874:22: error: invalid application of 'sizeof' to an incomplete type 'struct unix_syscall []'
sqlite3-binding.c:33883:22: error: invalid application of 'sizeof' to an incomplete type 'struct unix_syscall []'
sqlite3-binding.c:33910:20: error: invalid application of 'sizeof' to an incomplete type 'struct unix_syscall []'
sqlite3-binding.c:33927:16: error: invalid application of 'sizeof' to an incomplete type 'struct unix_syscall []'
sqlite3-binding.c:14469:38: note: expanded from macro 'ArraySize'
sqlite3-binding.c:33931:14: error: invalid application of 'sizeof' to an incomplete type 'struct unix_syscall []'
sqlite3-binding.c:14469:38: note: expanded from macro 'ArraySize'
sqlite3-binding.c:36584:11: warning: type specifier missing, defaults to 'int' [-Wimplicit-int]
sqlite3-binding.c:33727:49: note: expanded from macro 'osPread64'
sqlite3-binding.c:36696:17: warning: type specifier missing, defaults to 'int' [-Wimplicit-int]
sqlite3-binding.c:33745:57: note: expanded from macro 'osPwrite64'
```
咦～好像不行

### 0x011 第二次尝试
既然 Mac 上交叉编译不能用 CGO ，那我们就在 Docker 里面编就可以了吧。
```
➜ docker run --rm -v "$PWD":/Users/wentx/momaek/src/bot -w /Users/wentx/momaek/src/bot -e GOOS=linux -e GOARCH=amd64 -e CGO_ENABLED=1 -e GOPROXY='https://goproxy.cn,direct' golang:1.14 go build -v
.
.
.
...
➜ scp bot vps2:
```

然后在 vps 上执行：
```
> ./bot
./bot: /lib64/libc.so.6: version `GLIBC_2.28' not found (required by ./bot)
```
噢，还依赖 GLIBC_2.28 啊，咱装一个呗。
基本步骤：
```
wget http://ftp.gnu.org/gnu/glibc/glibc-2.28.tar.gz
tar zxvf glibc-2.28.tar.gz
cd glibc-2.28
mkdir build
cd build
../configure --prefix=/opt/glibc-2.28
make -j4
sudo make install
```
我们跟着一步一步走，到了
```
> ../configure --prefix=/opt/glibc-2.28
.
.
...
checking version of gmake... 3.82, bad
if gcc is sufficient to build libc... no

*** These critical programs are missing or too old: make bison compiler
```
看来，make,bison 和 gcc 需要升级或者安装。
我们先来看看版本
```
> make --version
GNU Make 3.82
Built for x86_64-redhat-linux-gnu
Copyright (C) 2010  Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
> 
> gcc --version
gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-39)
Copyright (C) 2015 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
> bison --version
-bash: bison: command not found (这货居然没有)
```
#### 安装 bsion
```
> wget https://ftp.gnu.org/gnu/bison/bison-3.2.tar.gz
> tar xf bison-3.2.tar.gz
> cd bison-3.2
> ./configure --prefix=/usr
> make
> make install
```
一步步走就可以，中间可能需要 m4，直接 `yum install m4 -y` 就可以。

#### 更新 make
```
> cd /tmp
> wget http://ftp.gnu.org/gnu/make/make-4.1.tar.gz
> tar xvf make-4.1.tar.gz
> cd make-4.1/
> ./configure
> make
> make install
> export PATH=/tmp/make-4.1:$PATH
> which gmake
/usr/bin/gmake
> rm /usr/bin/gmake
> ln -s /tmp/make-4.1/make /usr/bin/gmake
> make --version 
GNU Make 4.1
Built for x86_64-unknown-linux-gnu
Copyright (C) 1988-2014 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```

#### 更新 gcc
```
> yum install centos-release-scl
> yum install devtoolset-7-gcc*
> scl enable devtoolset-7 bash
> gcc --version
gcc (GCC) 7.3.1 20180303 (Red Hat 7.3.1-5)
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

回到 GLIBC_2.28 的安装，继续 
```
> ../configure --prefix=/usr
.
.
.
> make -j4
.
.
.（40分钟过去了）
.
.
> make install
.
.
```
安装完成。

最后执行：
```
> ./bot
(/Users/wentx/momaek/src/bot/main.go:64)
[2020-05-30 16:06:59]  [24.65ms]  CREATE TABLE "images" ("id" integer primary key autoincrement,"key" varchar(50),"user" varchar(50),"created_at" datetime,"deleted_at" datetime )
[0 rows affected or returned ]
```
OK