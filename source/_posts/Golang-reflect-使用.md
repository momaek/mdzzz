---
title: Golang reflect 使用
date: 2017-02-08 12:08:01
tags: Golang
photos: 
	- https://oa7ktymto.qnssl.com/golang.jpg
---

reflect 一个神奇的 pkg
<!--more-->


### 0x001
这篇文章写的时候使用的Go版本：`go version go1.7.1 darwin/amd64`

先来说一下背景，最近要做的一个项目对外暴露两个 API ，然后根据参数里面的 action 字段来决定后面的处理代码。 

首先想到的处理办法是：用一个 map 来存 action 和后面对应处理函数的关系，每次请求过来了就根据 map 里面的内容来决定。好，可以实现。听起来也比较简单，然后开始写代码。写了一段时间发现一个很坑爹的问题：
需要去维护一个 action 的 map 。有时候写完函数就忘记去添加到 map 里面了，就会出现 404 的错误，虽然知道是没有更新 map ，但是增加了开发的心里负担。然后在每个处理函数里面还需要去 parse 传过来的参数，是每个处理函数都要写一段基本相同的代码，就是下面这个东西

```
type A struct{}
type Args struct{}

func (a *A) Create(req *http.Request)(err error){
	args := Args{}
	params.BindValuesToStruct(&args, req) // 这个是自己写的一个函数
}
```
基本每个地方都会有，而且还需要去生成一个 client + logger。这个东西完全可以不用开发处理函数的人来关注的。他们只需要注重业务细节就好了。

### 0x010

接下来是如果改变这个东西，趁项目还不是很大，改起来还不是很麻烦。想到了用 reflect 包来解决这个问题。想到达到的效果是：
```
type A struct{}
type Args struct{}

func (a *A) Create(args  Args) (err error){}
// 需要的东西都在调用函数的之前搞定，函数里面就只专注业务，这个就把业务跟其他不相关的东西解耦了
```

### 0x011

既然决定使用 reflect 包，那么我们就来先看下 [官方文档](https://golang.org/pkg/reflect)(需要自己扶墙) 
```
reflect.TypeOf()
reflect.ValueOf()
```
两个简单的函数，`reflect.TypeOf` 和 `reflect.ValueOf`，返回被检查对象的类型和值。例如，x 被定义为：`var x float64 = 3.4`，那么 `reflect.TypeOf(x)` 返回 `float64`，`reflect.ValueOf(x)` 返回 `<float64 Value>`。

从上面的代码可以看出来，我们的处理函数都是 `A` 的方法，为了不去手动维护那个坑爹的 `map`。我们需要自己自动获取 `A` 的方法。如果我们的 `action` 跟 `A` 的方法名字一样的话，我们就可以不用关注 `map` 了。
```
typ := reflect.TypeOf(new(A))
typ.NumMethod // 这个返回 A 下面的方法数量，有了这个我们就可以知道 A 下面有多少方法了。 那么要怎么拿到这些方法呢？

typ.Method(i) // 这个函数返回 A 下面的第 i 个方法，返回值是 reflect.Method 

reflect 包里面 Method 的定义：
type Method struct {
	// Name is the method name.
	// PkgPath is the package path that qualifies a lower case (unexported)
	// method name. It is empty for upper case (exported) method names.
	// The combination of PkgPath and Name uniquely identifies a method
	// in a method set.
	// See https://golang.org/ref/spec#Uniqueness_of_identifiers
	Name    string
	PkgPath string

	Type  Type  // method type
	Func  Value // func with receiver as first argument 这条很重要
	Index int   // index for Type.Method
}

```
到这里，我们已经知道如何拿到一个 `struct` 下面的方法了。现在我们需要把这些方法存起来，存到一个 map 里面(不要怕，这个不需要手动维护，这个是程序直接做掉的)，直接来看代码：

```
// 此处我实现一个并发安全的map,实现了 Get,Set,Delete,Has 方法目前已经足够使用
// 如果想知道如何做，自行 Google 已经有很多了
type SafetyMap struct{
	sync.RWMutex
	item map[string]interface{} // action 的值就是map的key
}

// 这个是我们的主体，他的功能类似于 Mux ，所以我们就叫它 Mux
type Mux struct{
	m *SafetyMap
}

type Method struct{
	method reflect.Method // 这个是存 method
	args []reflect.Type // 这个存 method 对应的参数的 Type
}

func NewMux() *Mux{
	return &Mux{
		m: NewSafetyMap(), // 这个我在其他地方做掉了
	}
}

func (mux *Mux) Register(rcvr interface{}) {
	typ := reflect.TypeOf(rcvr) // 获取 rcvr 的Type

	for i := 0; i < typ.NumMethod(); i++ {
		method := typ.Method(i)
		mt := method.Type

		nOut := mt.NumOut() // 函数的返回值，如果返回值里面没有error那么直接panic
		if nOut < 1 {
			panic(fmt.Sprintf("%s return final output param must be error interface", method.Name))
		}
		_, ok := mt.Out(nOut - 1).MethodByName("Error") // 返回值的最后一个参数必须为 error
		if !ok {
			panic(fmt.Sprintf("%s return final output param must be error interface", method.Name))
		}

		m := Method{}
		m.method = method
		args := []reflect.Type{}
		for p := 1; p < mt.NumIn(); p++ { // 函数的参数
			args = append(args, mt.In(p)) // 参数必须跟本身函数参数的顺序相同，否则在调用函数的时候会出错
		}
		m.args = args

		mux.m.Set(method.Name, m)
	}
}
```
到这里，我们就把自动生成 `map` 的是事情做完了。
接下来我们来写调用函数处理的部分
```
func (mux *Mux) Call(key string, rcvr interface{}, req *http.Request) (interface{}, error) {
	safem, ok := mux.m.Get(key) // 获取到safemap的value
	if !ok {
		return nil, NotFound
	}

	method, ok := safem.(Method) // 断言一下 value 的类型看是不是我们想要的Method类型
	if !ok {
		return nil, NotFound
	}

	in := []reflect.Value{} // 调用函数的时候需要用到的参数列表
	
	// 第一个参数必须要是这个函数的rcvr，在reflect包的Method结构体里面有说这点，如果没有这做，程序会直接panic
	// panic: reflect: Call with too few input arguments 
	// 当时出现这个问题，我查了好久没有发现问题，然后看reflect包 Method的时候发现了这点
	// 这个的 rcvr 我们可以把一些需要用的东西提前准备好传进去，就不用在函数内部做这些事情了
	in = append(in, reflect.ValueOf(rcvr)) 

	
	// 拿到刚刚注册好的函数的参数
	// 按照顺序把参数
	for _, v := range method.Args {
		var (
			result interface{}
			val    reflect.Value
		)

		// reflect.New() 会返回指定类型的一个空值的指针 reflect.Value，
		// 根据上面的例子 这个会返回值的 type： *Args，type 的 Kind 是 reflect.Ptr
		// 该 type‘s Kind 是 reflect.Ptr 的 Elem() 方法会对应指针类型的值类型的 reflect.Value
		// reflect.Value 的 Interface() 方法是把该 Value 转成一个 interface
		result = reflect.New(v).Elem().Interface()

		// 这个 BindValuesToStruct 是在其他地方实现的，也是通过反射实现的，这个后面再来讲
		// 只需要知道这个函数会返回一个 reflect.Value 类型的值，而这个东西已经包含了传过来的参数
		val = params.BindValuesToStruct(result, req, true)
	
		in = append(in, val)
	}
	
	// 这个地方就是直接调用 Method 的 Func 属性下面的 Call() 方法，然后把参数传进去
	// 返回值是一个 []reflect.Value 类型
	ret := method.Method.Func.Call(in)


	// 这个地方我们需要解析出来最后一个 err 和 返回的结构体 默认就只有两个参数，其他的参数会被丢掉
	retLength := len(ret)
	var (
		err error
		res interface{}
	)

	// 因为我们在register里面强制要求了必须要有返回值而且最后一个返回值是 error，所以这个地方理论上讲是不会出现数组越界的
	err, _ = ret[retLength-1].Interface().(error)
	if retLength > 1 {
		res = ret[0].Interface()
	}

	return res, err
}
```
调用的函数也写完了。但是在测试的时候发现一个问题，如果我的处理函数的参数是指针类型的，例如：
```
func (a *A) Create(args *Args) (err error){}
```
这个时候直接就panic了，然后参数不能被正常的写入。这个地方我们的做法是在注入参数的时候把指针类型转换成值类型，然后在取这个值类型的指针。

```
在 Call() 函数里面

for _, v := range method.Args {
	var (
		result interface{}
		val    reflect.Value
	)

	// 判断是不是指针类型，如果是指针类型那么就在先拿他的elem来new
	// 否则就直接 new
	if v.Kind() == reflect.Ptr {
		result = reflect.New(v.Elem()).Elem().Interface()
		val = params.BindValuesToStruct(result, req, true).Addr()
	} else {
		result = reflect.New(v).Elem().Interface()
		val = params.BindValuesToStruct(result, req, true)
	}

	in = append(in, val)
}

```
这样就基本结束，当然这里面还是有一些问题：

* 不支持函数的参数是 struct 以外的其他类型
* =====

如果有看不明白的可以直接留言。
如果有出错的地方欢迎指正，相互学习。

代码： [github](https://github.com/momaek/mdzz)
