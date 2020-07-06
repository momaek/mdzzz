---
title: Golang1.9 HTTPS bug 排查记录
date: 2020-03-22 21:26:20
tags: Golang
photos: 
	- https://oa7ktymto.qnssl.com/golanghttps2.png
---
这个是一个Golang1.9的 Bug。当一个 HTTPS 链接客户端未知状态(没有 fin) `broken` 的时候，后续的 HTTPS 链接都会卡住。

### 0x001 
最近某天接到短信告警，portal.qiniu.com 的 API 不可用。查日志发现是请求 sso.qiniu.com 超时。浏览器打开 sso.qiniu.com 貌似没有问题，然后让运维同学帮忙排查一下网络问题。过了大概15分钟，收到服务恢复短信。

### 0x010
过了一会儿，告警短信又来了。查看 sso.qiniu.com 机器的监控，发现 sso.qiniu.com 服务的句柄如下图所示(前面几天的图没了， 简单画了一个)：

![](https://oa7ktymto.qnssl.com/WeChat764a584a7f88762aa808802b9868bc34.png)

从这个图我们可以看到，服务在12:00左右的时候句柄就开始涨了，到大概12:14:30左右开始断崖式下跌。在查这个监控的时候，句柄还在涨，然后重启了 sso.qiniu.com 服务，句柄恢复正常。紧接着就收到了服务恢复短信通知。

### 0x011

查看 sso.qiniu.com 的日志，发现在请求一个外部的 HTTPS 域名的时候有超时，如：
```
2020/03/09 12:01:19.793954 [ERROR] components/logger/transport.go:73: Service: POST xxxxxxxx/user/info, Code: 0, Err: http2: server sent GOAWAY and closed the connection; LastStreamID=1999, ErrCode=NO_ERROR, debug="", Time: 950750ms
```

然后查链接状态，发现大部分 socket 处于未正常被关闭的状态（CLOSE_WAIT、can't identify protocol、protocol: TCPv6），同时访问公网的 socket 个数很少。

推测大部分请求是卡在与外部服务建立连接之前，未正常被关闭的是 nginx 端已经断开连接。

然后接着看，发现只有一个 https 请求，而且处于 CLOSE_WAIT 状态，几台机器的状态都是一样。然后回去看 sso.qiniu.com 的日志，发现卡住的请求全是 https 请求。

推测问题出在了 https 请求处理上，我们这边不会对 https 请求做特殊处理，那么问题应该就出在 golang 的 net/http 库上。

再根据卡住的时间，基本上都在 14min30s 左右，与我们的 retransmission 整体的超时时间是匹配的（同时也恰好与 tcp keepalive 的超时时间差不多）。

restransmission 整体超时时间是 rto 超时后，重传，rto 翻倍，直到 TCP_RTO_MAX(我们是120s)，重传次数我们系统配置的是 15 次（net.ipv4.tcp_retries2 = 15），按初始 200~300ms 的 rto 算出来大约是 14min 左右。

再说一下 tcp keepalive，我们系统的设置是  intvl=75、probes=9、time=600，然后我们 Golang 里面把 intvl 改为了30，这样算出来时间刚刚好是 14min30s 左右。

然后 Golang 代码，发现了可能导致卡住的逻辑： https://github.com/golang/go/blob/ac7c0ee26dda18076d5f6c151d8f920b43340ae3/src/net/http/h2_bundle.go
```
一个正常的 https 请求的流程是，第一步获取链接，第二步写 header
step1. 获取链接
step1-1. 调用 http2clientConnPool.GetClientConn 获取一个可用的链接
step1-2. 拿 http2clientConnPool.mu 锁, line 738
step1-3. 调用 http2ClientConn.CanTakeNewRequest, line 740, 然后这个函数同样需要 http2ClientConn.mu 这个锁, line 7175

7174 func (cc *http2ClientConn) CanTakeNewRequest() bool {
7175	cc.mu.Lock()
7176	defer cc.mu.Unlock()
7177	return cc.canTakeNewRequestLocked()
7178 }


738         p.mu.Lock()                                                                              |8008                         ErrCode:      cc.goAway.ErrCode,                                        
739         for _, cc := range p.conns[addr] {                                                       |8009                         DebugData:    cc.goAwayDebug,                                           
740                 if cc.CanTakeNewRequest() {                                                      |8010                 }                                                                               
741                         p.mu.Unlock()                                                            |8011         } else if err == io.EOF {                                                               
742                         return cc, nil                                                           |8012                 err = io.ErrUnexpectedEOF                                                       
743                 }                                                                                |8013         }                                                                                       
744         }                                                                                        |8014         for _, cs := range cc.streams {                                                         
745         if !dialOnMiss {                                                                         |8015                 cs.bufPipe.CloseWithError(err) // no-op if already closed                       
746                 p.mu.Unlock()                                                                    |8016                 select {                                                                        
747                 return nil, http2ErrNoCachedConn                                                 |8017                 case cs.resc <- http2resAndError{err: err}:                                     
748         }                                                                                        |8018                 default:                                                                        
749         call := p.getStartDialLocked(addr)                                                       |8019                 }                                                                               
750         p.mu.Unlock() 



step2. 写 header
step2-1. 拿 http2ClientConn.mu 锁, line 7335
step2-2. 调用 http2ClientConn.writeHeaders 去写 header
step2-3. http2ClientConn.writeHeaders 调用 bw.Flush（有潜在的卡住风险）
step2-4. 释放 http2ClientConn.mu 锁 line 7384

7335	cc.mu.Lock()
	......
7382	cc.wmu.Lock()
7383	endStream := !hasBody && !hasTrailers
7384	werr := cc.writeHeaders(cs.ID, endStream, int(cc.maxFrameSize), hdrs)
7385	cc.wmu.Unlock()
7386	http2traceWroteHeaders(cs.trace)
7387	cc.mu.Unlock()
```
在上面的步骤中，如果在写 header 的时候卡在了`step2-3`，那么后续的向同一个地址的请求都会卡在`step1-3`。然后后续的 https 请求都会被卡在`step1-2`，直到`step2-3`处理结束。

再来说说 CLOST_WAIT，CLOSE_WAIT 状态下，read 立即返回，按理会关闭 socket，让 write 也立即返回，但是 olang 的代码里关闭 socket 之前，又执行了一个需要请求 cc.mu lock 的逻辑，相当于这里也被卡住了: https://github.com/golang/go/blob/e8a95aeb75536496432bcace1fb2bbfa449bf0fa/src/net/http/h2_bundle.go#L8232 。结合服务的错误日志，基本都是 write connnection timed out，基本上命中重传超时了。

### 0x100
既然找到问题了，那么接下来就是如何解决了。因为我们服务用的是 Golang1.9，本质上其实升级 Golang 应该可以解决问题，但是我们升级到了 Go1.11 这个问题貌似也还是存在。如何测试问题是否存在：
```
package main

import (
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"strings"
	"sync/atomic"
	"time"
)

var url = flag.String("url", "https://172.28.128.3:12345/test", "url")

func main() {

	flag.Parse()

	var reqA, doneA int64
	var reqB, doneB int64
	for {
		for i := 0; i < 10; i++ {
			go func() {
				atomic.AddInt64(&reqA, 1)
				resp, err := http.Get("https://www.qiniu.com")
				if err == nil {
					io.Copy(ioutil.Discard, resp.Body)
					resp.Body.Close()
				}
				atomic.AddInt64(&doneA, 1)
			}()
		}
		for i := 0; i < 10; i++ {
			go func() {
				atomic.AddInt64(&reqB, 1)
				req, _ := http.NewRequest("GET", *url, nil)
				req.Header.Set("X-Qiniu", strings.Repeat("helloworld", 1024))
				resp, err := http.DefaultClient.Do(req)
				if err == nil {
					io.Copy(ioutil.Discard, resp.Body)
					resp.Body.Close()
				}
				atomic.AddInt64(&doneB, 1)
			}()
		}

		fmt.Printf("reqA:%d doneA:%d, reqB:%d doneB:%d\n", atomic.LoadInt64(&reqA), atomic.LoadInt64(&doneA), atomic.LoadInt64(&reqB), atomic.LoadInt64(&doneB))

		time.Sleep(1e9)
	}
}
```
运行上面的代码，然后拔掉 172.28.128.3 这台机器的电源。然后就会发现所有请求的卡住了
```
[18:16:08]~/code/go $ go run test.go 
2020-03-16 18:16:54 reqA:2 doneA:0, reqB:1 doneB:0
2020-03-16 18:16:55 reqA:12 doneA:10, reqB:11 doneB:6
2020-03-16 18:16:56 reqA:21 doneA:20, reqB:20 doneB:20
2020-03-16 18:16:57 reqA:33 doneA:30, reqB:31 doneB:30
2020-03-16 18:16:58 reqA:44 doneA:40, reqB:41 doneB:40
2020-03-16 18:16:59 reqA:52 doneA:50, reqB:50 doneB:50
2020-03-16 18:17:00 reqA:62 doneA:60, reqB:62 doneB:60
2020-03-16 18:17:01 reqA:72 doneA:70, reqB:71 doneB:60
2020-03-16 18:17:02 reqA:83 doneA:79, reqB:81 doneB:60
2020-03-16 18:17:03 reqA:92 doneA:79, reqB:91 doneB:60
2020-03-16 18:17:04 reqA:101 doneA:79, reqB:101 doneB:60
2020-03-16 18:17:05 reqA:110 doneA:79, reqB:110 doneB:60
2020-03-16 18:17:06 reqA:122 doneA:79, reqB:122 doneB:60
2020-03-16 18:17:07 reqA:132 doneA:79, reqB:130 doneB:60
2020-03-16 18:17:08 reqA:141 doneA:79, reqB:141 doneB:60
2020-03-16 18:17:09 reqA:151 doneA:79, reqB:151 doneB:60
2020-03-16 18:17:10 reqA:162 doneA:79, reqB:161 doneB:60
2020-03-16 18:17:11 reqA:171 doneA:79, reqB:171 doneB:60
2020-03-16 18:17:12 reqA:187 doneA:79, reqB:181 doneB:60
2020-03-16 18:17:13 reqA:193 doneA:79, reqB:192 doneB:60
```

这里在说说拔电源和 kill 服务的区别
Kill 服务：
client socket 会收到 FIN 包，然后状态变成 CLOSE_WAIT
读操作会立即返回 EOF
写操作通常会失败，然后收到一个 RST 的返回

拔电源：
没有 FIN 包，client socket 啥也不知道
读操作会一直卡住，直到 tcp keepalive timed out 或者其他一些奇怪的事情发生
写操作也一样

### 0x101
Go1.12，Go1.13，Go1.14 没有测试过。
我们用的解决办法是，新建了一个 http.Client 实例，自定义了 net.Transport 和 net.Dailer.
```
client := &http.Client{
	Transport: &http.Transport{
		Dial: (&net.Dialer{
		}).Dial,
	},
	Timeout: 5 * time.Second,
}
```

以上