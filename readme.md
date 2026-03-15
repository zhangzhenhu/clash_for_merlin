# Clash for Merlin

为华硕路由器梅林固件（asuswrt-merlin）打造的 Clash 代理插件。

> 参考官方文档：https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API

> 注意：固件版本必须 ``384.15`` 以上才支持插件方式。

---

## 支持的路由器

| 架构 | 型号示例 |
|------|----------|
| arm64 (64位) | RT-AX86U, RT-AX88U, RT-AX92U, RT-AX58U, RT-AX3000 等 |
| armv7 (32位) | RT-AC68U, RT-AC88U, RT-AC3100, RT-AC3200, RT-AC87U 等 |

---

## 安装

### 1. 下载安装包

访问 [GitHub Release](https://github.com/zhangzhenhu/clash_for_merlin/releases) 页面，根据路由器架构下载对应的安装包：

- `clash_for_merlin_mihomo-linux-arm64-*.tar.gz` - 64位路由器 (AX86U, AX88U 等)
- `clash_for_merlin_mihomo-linux-armv7-*.tar.gz` - 32位路由器 (AC68U, AC88U 等)

### 2. 上传到路由器

```shell
# 通过 SCP 上传
scp clash_for_merlin_mihomo-linux-arm64-*.tar.gz admin@192.168.50.1:/tmp/
```

### 3. 安装

```shell
# SSH 登录路由器
ssh admin@192.168.50.1

# 解压到 jffs 分区
cd /tmp
tar -xzf clash_for_merlin_mihomo-linux-arm64-*.tar.gz -C /jffs/addons/
cd /jffs/addons/clash_for_merlin

# 设置权限并执行安装
chmod +x *.sh
sh ./init.sh
```

---

## 使用方法

### Web 管理界面

1. 浏览器登录路由器管理页面
2. 点击左侧 **Tools**
3. 在 Tools 里能看到 **Clash** 标签页

- **Clash 管理界面**: http://路由器IP:9090/ui
- **API 地址**: http://路由器IP:9090

### 终端代理配置

在 Clash 页面 Basic Info 标签页底部，可以找到终端代理配置命令：

```shell
export https_proxy=http://192.168.50.1:7890 http_proxy=http://192.168.50.1:7890 all_proxy=socks5://192.168.50.1:7891
```

复制后在终端中运行即可使用代理。

### 代理节点测速

在 **代理节点** 标签页可以：
- 查看所有代理节点状态
- 点击「测速」按钮测试单个节点延迟
- 点击「测速全部节点」批量测试所有节点

---

## 关于存储空间

### 二进制文件处理

由于 `/jffs` 分区空间有限（通常只有 30-50MB），mihomo 二进制文件（约 25-40MB）以 gzip 压缩格式存储在 `binaries/` 目录中。

**工作原理：**

1. 开机时 `service-start.sh` 自动把压缩的二进制文件解压二到 `/tmp/clash`
2. 通过软链接 `/jffs/addons/clash_for_merlin/bin/clash` 指向 `/tmp/clash`
3. `/tmp` 分区通常空间较大（256MB+），足够存放解压后的二进制

**手动解压（可选）：**

如果需要手动解压：

```shell
cd /jffs/addons/clash_for_merlin/binaries
gzip -d mihomo-linux-arm64-*.gz -c > /tmp/clash
chmod +x /tmp/clash
```

---

## 编译自定义 mihomo

如果你想使用自己编译的 mihomo：

### 1. 编译

```shell
# arm64
make linux-arm64

# armv7
make linux-armv7
```

### 2. 替换二进制

将编译好的二进制文件复制到 `binaries/` 目录：

```shell
# 压缩
gzip -c mihomo > binaries/mihomo-linux-arm64-v版本号.gz

# 或直接复制到 /tmp（测试用）
cp mihomo /tmp/clash
chmod +x /tmp/clash
```

> 注：本项目的 mihomo 已经包含用于读写 YAML 配置文件的扩展 API。

---

## 卸载

```shell
cd /jffs/addons/clash_for_merlin
sh ./uninstall.sh
```

---

## 技术说明

- 使用 mihomo (Meta 内核) 而非原版 Clash，功能更强大
- 通过 RESTful API 实现配置管理，避免 Web 界面无法处理大文件的限制
- 使用 bind mount 技术动态修改路由器菜单，无需修改系统文件
- 二进制压缩存储节省 jffs 空间
