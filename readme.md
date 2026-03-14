# Clash for Merlin

为华硕路由器梅林固件（asuswrt-merlin）打造的 Clash 代理插件。

> 参考官方文档：https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API

## 特性

- 支持 armv7 / armv8 架构
- 集成 yacd Web UI
- 通过 RESTful API 管理配置
- 开机自动恢复菜单

> 注意：固件版本必须 ``384.15`` 以上才支持插件方式。

---

## 安装方式

### 方式一：一键安装（推荐）

> ⚠️ 需要路由器能访问 GitHub

```shell
curl -sL https://github.com/zhangzhenhu/clash_for_merlin/releases/latest/download/install.sh | sh
```

### 方式二：手动安装

如果路由器无法访问 GitHub（如没有代理），可按以下步骤操作：

#### 1. 在电脑上下载安装包

访问 GitHub Release 页面下载：
- https://github.com/zhangzhenhu/clash_for_merlin/releases

下载以下文件：
- `clash_for_merlin.tar.gz` - 安装包
- `install.sh` - 安装脚本

#### 2. 上传到路由器

```shell
# 通过 SCP 上传（替换为你的路由器 IP）
scp clash_for_merlin.tar.gz admin@192.168.1.1:/tmp/
scp install.sh admin@192.168.1.1:/tmp/
```

#### 3. 在路由器上执行安装

```shell
# SSH 登录路由器
ssh admin@192.168.1.1

# 解压并安装
cd /tmp
tar -xzf clash_for_merlin.tar.gz -C /jffs/addons/
cd /jffs/addons/clash_for_merlin

# 设置权限
chmod +x *.sh
chmod +x bin/*

# 执行安装
sh ./init.sh
```

---




## 使用方法

1. 浏览器登录路由器管理网站
2. 点击左侧工具栏 **Tools**
3. 在 Tools 里能看到一个名为 **Clash** 的 tab 页

### Web UI

- ** Clash 管理界面**: http://路由器IP:9090/ui
- ** API 地址**: http://路由器IP:9090

---

## 编译 Clash

如果你对我提供的 ``clash`` 不放心，可以自己去找 ``clash`` 的开源代码，然后按照下面的说明自己改下代码重新编译即可。

> 注：原版 Clash 的 RESTful API 不能直接读写 YAML 配置文件，本项目使用了魔改版的 Clash，增加了几个 API 用于读写 yml 配置文件。

### 步骤 1：增加代码文件

把文件 ``clash_patch/hub/route/yml.go`` 放到 ``clash`` 源码相同的的路径 ``hub/route/yml.go`` 下。

### 步骤 2：修改文件

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

### 步骤 3：编译 clash

重新编译 clash，编译命令。

按照你的设备芯片架构选择

```shell
# armv8  
make linux-armv8 

```

```shell
# armv7  
make linux-armv7

```

编译完成后，为文件增加可执行权限。

```shell
chmod +x bin/*

```

### 步骤 4：

用你编译好的文件，替换本项目 ``bin/`` 目录下对应的文件即可。

---

## 技术说明

官方的插件机制功能非常有限，最大的限制是 Web 界面和后端没办法交互很大体积的配置信息。恰好 Clash 的配置文件一般又很大，尤其那些代理规则。这导致无法在 Web 界面管理这些配置。

本项目走了一条邪路：利用 Clash 的 RESTful API 实现配置的交互。然而 Clash 本身自带的 RESTful API 功能有限，不能直接读写 YML 配置文件。所以魔改了一下 Clash 源码，增加了几个 API，用于读写 YML 配置文件。

路由器是 AX86U，芯片是 ``armv8``。项目在 ``bin/`` 下面同时放了 ``armv7`` 和 ``armv8`` 两个版本的二进制执行文件，脚本可以自动根据当前芯片适配选择对应的文件。

---

## 卸载

```shell
# 方式一：一键卸载
curl -sL https://github.com/zhangzhenhu/clash_for_merlin/releases/latest/download/uninstall.sh | sh

# 方式二：手动卸载
cd /jffs/addons/clash_for_merlin
sh ./uninstall.sh
```
