# 哈哈

又来瞎几把折腾了。

为华硕路由器原版的梅林固件（asuswrt-merlin）弄一个 clash 的插件。

参靠官方文档：

https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API


官方的这个插件机制功能非常有限，最大的一个限制是web 界面和后端没办法交互很大体积的配置信息，恰好 clash 的配置文件一般又很大，尤其那些代理规则。这导致无法在 web 界面管理这些配置。


最后走了一条邪路，就是利用 clash 的 restful api 实现配置的交互。然而 clash 本身自带的restful API 功能有限，不能直接读写 yml 配置文件，没办法自己找到 clash 的源码（原作者已经删库跑路了，幸好提前做了备份）魔改了一下，增加了几个 API，用于读写 yml 配置文件。


我的路由器是 AX86U，芯片是 armv7 的。为了大家方便，我在 ``bin/`` 下面同时放了 ``armv7`` 和 ``armv8`` 两个版本的二进制执行文件，脚本可以自动根据当前芯片适配选择对应的文件。

如果你对我提供的 ``clash`` 不放心，可以自己去找 ``clash`` 的开源代码，然后按照下面的说明自己改下代码重新编译即可。


**步骤 1：增加代码文件**

把文件 ``clash_patch/hub/route/yml.go`` 放到 ``clash`` 源码相同的的路径 ``hub/route/yml.go`` 下。

**步骤 2：修改文件**

如下所示，修改``clash`` 源码文件 ``hub/route/server.go``

```go

	r.Use(cors.Handler)
	r.Group(func(r chi.Router) {
		r.Use(authentication)

		r.Get("/", hello)
		r.Get("/logs", getLogs)
		r.Get("/traffic", traffic)
		r.Get("/version", version)
		r.Mount("/configs", configRouter())
		r.Mount("/proxies", proxyRouter())
		r.Mount("/rules", ruleRouter())
		r.Mount("/connections", connectionRouter())
		r.Mount("/providers/proxies", proxyProviderRouter())
        // 找到这个位置
		r.Mount("/yml", ymlRouter()) // Add this line
	})

```


**步骤 3：编译 clash**

重新编译 clash，编译命令。

按照你的设备芯片架构选择

```shell
# armv8  
make linux-armv8 

```

```shell
# armv8  
make linux-armv7

```

编译完成后，为文件增加可执行权限。

```shell
chmod +x cp bin/*

```

**步骤 4：**

用你编译好的文件，替换本项目 ``bin/`` 目录下对应的文件即可。

