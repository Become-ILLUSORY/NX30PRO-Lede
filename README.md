# NX30PRO-Lede

H3C Magic NX30 Pro 的 OpenWrt 云编译仓库。

[![Build](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/openwrt-builder.yml/badge.svg?branch=chasey-25.12-honk)](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/openwrt-builder.yml)
[![geo-mini](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/geo-mini.yml/badge.svg?branch=chasey-25.12-honk)](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/geo-mini.yml)

| 项 | 值 |
|---|---|
| 硬件 | MT7981B（2×Cortex-A53 @1.3GHz）/ 256MB DDR / 128MB NAND |
| 源码树 | [`chasey-dev/immortalwrt-mt798x-rebase`](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) @ `25.12` |
| 内核 | **6.12.112**（honk 要求 6.12+） |
| 机型 | `h3c_magic-nx30-pro-mtkuboot`（MTK U-Boot layout） |
| 包管理 | **apk**（OpenWrt 25.12 起） |
| ubi 分区 | **64 MB** |

---

## 分支

| 分支 | 源码树 | 内核 | 说明 |
|---|---|---|---|
| `padavanonly` | padavanonly/immortalwrt-mt798x-6.6 @ openwrt-24.10-6.6 | 6.6 | 历史版本，opkg |
| **`chasey-25.12-honk`** | **chasey-dev/immortalwrt-mt798x-rebase @ 25.12** | **6.12** | 当前，为 honk 准备 |

---

## 两个工作流

| 工作流 | 产物 | 耗时 |
|---|---|---|
| `openwrt-builder.yml` | 固件（不含 geo、不含 honk） | ~1.5 小时 |
| `geo-mini.yml` | 两个 geo 数据 apk（0.899 MB） | ~1 分钟 |

**为什么拆开**：geo 数据几乎每天更新，honk 又会自己维护它。编进固件只会固定在编译那一刻，且 squashfs 压缩后仍占 0.47 MB。拆成独立小包后固件更小，数据更新也不必重编固件。

---

## 固件内容

- **代理**：不含任何代理内核。honk 从 [`openwrt.daeuniverse.org`](https://openwrt.daeuniverse.org/zh-cn/) 在线安装，可独立更新。
- **geo 数据**：**不含**，见「geo 小包」一节。
- **硬件加速**：HNAT（`kmod-mediatek_hnat`）+ MTK WARP（`kmod-warp`，含 MT7981 WOCPU 固件）+ turboacc
- **内存**：zram 用 **zstd**（容量为 RAM 一半，等效约 3×）
- **拥塞控制**：BBR v1 + `fq`（`kmod-sched`）
- **端口映射**：`natmap` + LuCI
- **Web**：LuCI + argon 主题

### 相对上游 defconfig 的改动

| 改动 | 说明 |
|---|---|
| 单机型 | 92 机型全家桶裁到只剩 `h3c_magic-nx30-pro-mtkuboot` |
| **移除 geo** | 改为独立小包，见下 |
| squashfs 块 1 MiB | 默认 256 KiB，压缩率提升约 5% |
| 关闭模块 BTF | `KERNEL_DEBUG_INFO_BTF_MODULES` 改 `def_bool n`，不给几百个 `.ko` 生成 BTF 段 |
| 删无用包 | 无 USB/SATA 机型用不到的存储栈（11 个包） |
| 去掉 `luci-app-eqos-mtk` / `mtkhqos_util` |

### 为 honk 准备的内核能力

```conf
CONFIG_KERNEL_DEBUG_INFO_BTF=y      # eBPF CO-RE 需要 /sys/kernel/btf/vmlinux
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_NETKIT=y
```

`kernel-config-6.12.append` 追加：

```conf
CONFIG_CGROUP_BPF=y
CONFIG_SOCK_CGROUP_DATA=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NETKIT=y
```

外加 7 个 kmod：`veth` / `sched-core` / `sched-bpf` / `nft-core` / `nft-queue` / `nfnetlink-queue` / `nf-conntrack`。

---

## geo 小包

**为什么需要**：honk 的 `Makefile` 硬依赖 `v2ray-geoip` + `v2ray-geosite`，官方全量版装完占 **24 MB**。

**极简版**（`geo-mini/`）：

| apk | 安装后 | 内容 |
|---|---|---|
| `v2ray-geoip` | **238 KB** | 只含 CN + PRIVATE |
| `v2ray-geosite` | **705 KB** | 只含 `GEOLOCATION-CN` / `GEOLOCATION-!CN` / `CATEGORY-ADS-ALL` |
| **合计** | **0.899 MB** | |

**为什么不能做成空包**：honk 的 `native_api/geodata.rs` 里 `updatable()` 要求 `assets` 非空，而自动更新和手动更新（`POST /api/v1/geodata/update`）共用 `queue()`。没有文件 → `assets` 为空 → 永不下载 → **死锁**。所以必须放真实文件当种子。

**版本号 `99999999999999999999`（20 位）**：官方两个包的版本位数不同（`geoip` 12 位、`geosite` 14 位），apk 按数值比较，位数不够会被判成 downgrade 而被换回全量包。

**软链**：`/usr/share/honk/*.dat -> ../v2ray/*.dat` 由 **honk 包自己**安装，geo 包不能重复创建（会触发 apk 文件冲突）。

---

## 已验证的构建结果

最近一次成功构建：固件 **`2026.10.29-1212`** + geo **`geo-mini-2026.10.29-1052`**

| 产物 | 大小 |
|---|---|
| `...-squashfs-factory.bin` | **18.75 MB** |
| `...-squashfs-sysupgrade.bin` | **17.20 MB** |
| `...-initramfs-kernel.bin` | 16.64 MB |

镜像内部实测（解包后核对，非推测）：

| 项 | 实测 |
|---|---|
| 包数量 | **258**（比含 geo 的版本少 2 个） |
| rootfs (squashfs) | 11.54 MB，**xz**，**块 1 MiB** |
| kernel | 5.65 MB |
| `/usr/share/v2ray` | **不存在** ✓ 确认 geo 未编入 |
| `usr/bin/honk-core` | **不存在** ✓ 确认 honk 未编入 |
| `lib/firmware/7981_WOCPU0_RAM_CODE_release.bin` | 2.45 MB ← WARP 芯片配置为 mt7981 |
| `etc/uci-defaults/99-zram-zstd` | ✓ zram 开机自动用 zstd |

### 离线验证范围

固件 rootfs 是 aarch64 + musl，与 x86_64 宿主的 Linux 沙箱同架构，可以 `chroot` 进去跑真实二进制。已验证：

```
✅ 1446 个文件解包完整
✅ 11 个核心二进制全部可执行（busybox/uci/apk/uhttpd/fw4/nft/natmap/procd）
✅ 32 个 init 脚本语法正确
✅ 35 个 uci-defaults 执行成功
✅ 首次启动：zram_comp_algo=zstd / swappiness=100 / mediaurlbase=/luci-static/argon
✅ LuCI 静态资源可取（luci.js 29KB / favicon 9KB）+ 22 个 JSON 全合法
✅ geo 小包安装，honk 通过软链读到
✅ honk 启动、Vless(REALITY)/Hysteria2/Shadowsocks 解析、4 条规则编译
✅ honk Clash API :9090 正常
✅ honk 内嵌 doona 面板 :9527/ui 完整可用（中文）
```

**无法离线验证**（必须真机）：LuCI 后台（CGI 在 chroot/PRoot 下 500，属环境限制非固件缺陷）、内核真实启动、WiFi 驱动、eBPF 数据面、HNAT 实际加速、分区刷写。

---

## 刷机

### 首次 / 从旧固件

MTK U-Boot 的 web 恢复界面刷：

```
immortalwrt-mediatek-filogic-h3c_magic-nx30-pro-mtkuboot-squashfs-factory.bin
```

### 已在同布局 OpenWrt 上

```sh
sysupgrade -n /tmp/immortalwrt-...-squashfs-sysupgrade.bin
```

⚠️ 本机型是 **MTK U-Boot layout**，与 `h3c_magic-nx30-pro`（OpenWrt U-Boot layout）镜像**不通用**，互相刷会砖。

---

## 刷完装 honk

**顺序不能乱。** geo → BTF → honk：

### 1. geo 小包（honk 的硬依赖）

从 [geo-mini Release](https://github.com/Become-ILLUSORY/NX30PRO-Lede/releases) 下载后：

```sh
apk add --allow-untrusted /tmp/v2ray-geoip-99999999999999999999-r1.apk \
                           /tmp/v2ray-geosite-99999999999999999999-r1.apk
```

### 2. 导入公钥 + 加源

```sh
wget -O /etc/apk/keys/daeuniverse.pem https://openwrt.daeuniverse.org/public-key.pem

# 只加 packages 源；不要加 kmods 源（自编内核装不了官方 vmlinux-btf）
. /etc/openwrt_release
echo "@daeuniverse https://openwrt.daeuniverse.org/${DISTRIB_RELEASE%.*}/packages/$DISTRIB_ARCH/packages.adb" \
  > /etc/apk/repositories.d/daeuniverse.list
apk update
```

### 3. BTF 占位包

```sh
apk add --allow-untrusted vmlinux-btf-builtin@daeuniverse
```

> 这一步会校验 `/sys/kernel/btf/vmlinux`，装不上说明内核 BTF 没编进去。

### 4. honk

```sh
apk add honk@daeuniverse luci-app-honk@daeuniverse luci-i18n-daeuniverse-zh-cn@daeuniverse

uci set honk.config.enabled=1 && uci commit honk
/etc/init.d/honk enable && /etc/init.d/honk start
```

### 5. 配 geo 更新源（**关键**）

编辑 `/etc/honk/config.dae`：

```dae
assets {
    route: direct
    geodata {
        geoip:   'https://fastly.jsdelivr.net/gh/v2fly/geoip@release/geoip-only-cn-private.dat'
        geosite: 'https://fastly.jsdelivr.net/gh/v2fly/domain-list-community@release/dlc.dat'
        route: direct
    }
}
```

⚠️ **不能用 GitHub release 的 `latest/download` 链接** —— 那是 302 重定向，honk 文档明确要求 *"no redirects"*，会直接拒绝。`fastly.jsdelivr.net` 实测无重定向且内容与官方 sha256 一致。

### 6. 立刻拉最新 geo

honk 的首次自动检查是**开机后 5~65 分钟随机**（`STARTUP_DELAY=300s` + `jitter 0~3600s`，目的是避免大量设备同时下载）。想立刻生效就手动触发：

```sh
curl -X POST http://127.0.0.1:9527/api/v1/geodata/update
curl http://127.0.0.1:9527/api/v1/geodata        # 看 last_updated_at
```

---

## 刷完自检

```sh
ls -l /sys/kernel/btf/vmlinux                                  # 非空 = BTF 正常
du -h /usr/share/v2ray/geoip.dat                               # 0.23M = geo 小包装对了
ls -l /usr/share/honk/geoip.dat                                # 软链 -> ../v2ray/geoip.dat
cat /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep '\['   # [zstd]
sysctl net.ipv4.tcp_congestion_control                         # bbr
```

HNAT 需要在 LuCI 里手动打开（`turboacc` 默认关闭）。honk 对直连流量有 direct offload，直连仍走硬件加速；只有走代理的流量受 CPU 限制。

---

## 网页后台

装好 honk 后有两套后台：

| 后台 | 地址 | 说明 |
|---|---|---|
| **honk (doona)** | `http://127.0.0.1:9527/ui` | 内嵌，需 SSH 端口转发 |
| LuCI | `http://192.168.1.1` | OpenWrt 原生 |

doona 面板默认只监听 loopback：

```sh
ssh -L 9527:127.0.0.1:9527 root@192.168.1.1
# 浏览器打开 http://127.0.0.1:9527/ui
```

Clash API 在 `127.0.0.1:9090`。

---

## ⚠️ 升级注意

```sh
apk upgrade honk          # ✅ 只升 honk
apk upgrade               # ❌ 64MB 机器上全量升级有风险（kmod 可能和自编内核 ABI 不匹配）
```

geo 小包版本号是 20 位，`apk upgrade` 不会把它换回 24 MB 全量版。但如果官方包将来用了更长的版本号，需要同步加长。

---

## geo 需要更多分类时

`geosite` 只保留了 3 个分类。要用 `netflix` / `openai` / `category-games` 等：

```sh
curl -sL -o dlc.dat https://fastly.jsdelivr.net/gh/v2fly/domain-list-community@release/dlc.dat
# 编辑提取脚本的 KEEP 列表，重新生成 geo-mini/files/geosite.dat
# 然后跑 geo-mini 工作流
```

注意 `geosite: cn` 和 `geosite: geolocation-cn` 是**不同分类**，只保留了后者（dae 生态的标准写法）。

---

## 本地编译

```sh
git clone https://github.com/chasey-dev/immortalwrt-mt798x-rebase -b 25.12 openwrt
cd openwrt
cat ../kernel-config-6.12.append >> target/linux/mediatek/filogic/config-6.12
cp -r ../files .
cp ../H3C-NX30PRO.config .config
./scripts/feeds update -a && ./scripts/feeds install -a
sh ../diy-part1.sh && sh ../diy-part2.sh
make defconfig && make -j$(nproc)
```

geo 小包单独编（需要 25.12.6 SDK）：

```sh
# 放进 SDK 的 package/ 目录，选中后
make package/v2ray-geo-mini/compile
```

---

## 致谢

- [chasey-dev](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) —— MT798x 源码树与 MTK 补丁
- [padavanonly](https://github.com/padavanonly/immortalwrt-mt798x-6.6) —— HNAT 补丁栈
- [daeuniverse](https://github.com/daeuniverse/honk) —— honk / dae
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) —— 工作流模板
