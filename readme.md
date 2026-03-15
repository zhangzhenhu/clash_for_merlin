# Clash for Merlin

为华硕路由器梅林固件（asuswrt-merlin）打造的 Clash 代理插件。

> 参考官方文档：https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API

## 特性

- 支持 armv7 / arm64 架构（自动检测）
- 默认使用 mihomo 内核
- 集成 yacd Web UI
- 通过 RESTful API 管理配置
- 开机自动恢复菜单

> 注意：固件版本必须 ``384.15`` 以上才支持插件方式。

---

## 安装方式

### 方式一：一键安装（推荐）

> ⚠️ 需要路由器能访问 GitHub

安装脚本会自动检测路由器架构并选择对应的 mihomo 版本。

```shell
curl -sL https://github.com/zhangzhenhu/clash_for_merlin/releases/latest/download/install.sh | sh
```

**支持的路由器型号：**

| 架构 | 型号示例 |
|------|----------|
| arm64 (64位) | RT-AX86U, RT-AX88U, RT-AX92U, RT-AX58U, RT-AX3000 等 |
| armv7 (32位) | RT-AC68U, RT-AC88U, RT-AC3100, RT-AC3200, RT-AC87U 等 |

### 方式二：手动安装

如果路由器无法访问 GitHub（如没有代理），可按以下步骤操作：

#### 1. 在电脑上下载安装包

访问 GitHub Release 页面下载：
- https://github.com/zhangzhenhu/clash_for_merlin/releases

根据你的路由器架构选择对应的安装包：

- `clash_for_merlin_mihomo-linux-arm64-v1.19.21.tar.gz` - 64位路由器 (AX86U, AX88U 等)
- `clash_for_merlin_mihomo-linux-armv7-v1.19.21.tar.gz` - 32位路由器 (AC68U, AC88U 等)

同时下载 `install.sh` 脚本。

#### 2. 上传到路由器

```shell
# 通过 SCP 上传（替换为你的路由器 IP 和架构对应的文件名）
scp clash_for_merlin_mihomo-linux-arm64-v1.19.21.tar.gz admin@192.168.1.1:/tmp/
scp install.sh admin@192.168.1.1:/tmp/
```

#### 3. 在路由器上执行安装

```shell
# SSH 登录路由器
ssh admin@192.168.1.1

# 解压并安装
cd /tmp
tar -xzf clash_for_merlin_mihomo-linux-arm64-v1.19.21.tar.gz -C /jffs/addons/
cd /jffs/addons/clash_for_merlin

# 设置权限
chmod +x *.sh

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

本项目利用 mihomo 的 RESTful API 实现配置的交互。mihomo (formerly clash.meta) 是一款增强版的 Clash 核心，支持完整的配置管理功能。

路由器是 AX86U，芯片是 ``arm64``。项目在 release 中提供了多种架构的 mihomo 二进制文件，install.sh 会自动根据当前芯片选择对应的版本。

---

## 卸载

```shell
# 方式一：一键卸载
curl -sL https://github.com/zhangzhenhu/clash_for_merlin/releases/latest/download/uninstall.sh | sh

# 方式二：手动卸载
cd /jffs/addons/clash_for_merlin
sh ./uninstall.sh
```
