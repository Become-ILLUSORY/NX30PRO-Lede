# NX30PRO-Lede

H3C Magic NX30 Pro（MT7981B / 256MB RAM / 128MB NAND）的 OpenWrt 云编译。

| 项 | 值 |
|---|---|
| 源码树 | `chasey-dev/immortalwrt-mt798x-rebase` @ `25.12` |
| 内核 | **6.12**（honk 要求 6.12+） |
| 机型 | `h3c_magic-nx30-pro-mtkuboot`（MTK U-Boot layout） |
| 包管理 | apk（OpenWrt 25.12 起） |

## 分支说明

| 分支 | 源码树 | 说明 |
|---|---|---|
| `padavanonly` | padavanonly/immortalwrt-mt798x-6.6 @ openwrt-24.10-6.6 | 内核 6.6，历史版本 |
| `chasey-25.12-honk` | **chasey-dev/immortalwrt-mt798x-rebase @ 25.12** | 当前分支，内核 6.12，为 honk 做准备 |

## 这个分支做了什么

### 1. 精简到单机型
从 `defconfig/mt7981-ax3000.config` 出发（92 机型全家桶）裁到只剩 `h3c_magic-nx30-pro-mtkuboot`。

### 2. 为 honk 准备内核能力
honk 从 `openwrt.daeuniverse.org` 在线安装（不编进固件，便于更新），但它的内核依赖必须内建：

- `CONFIG_KERNEL_DEBUG_INFO_BTF=y` —— honk 的 eBPF 对象做 CO-RE，需要 `/sys/kernel/btf/vmlinux`
- `# CONFIG_KERNEL_DEBUG_INFO_BTF_MODULES is not set` —— 不给每个 .ko 塞 BTF，省空间
- `CONFIG_KERNEL_CGROUPS=y` + `CONFIG_KERNEL_NETKIT=y`
- `kernel-config-6.12.append` 追加 `CGROUP_BPF` / `SOCK_CGROUP_DATA` 等
- 7 个 kmod：`veth` / `sched-core` / `sched-bpf` / `nft-core` / `nft-queue` / `nfnetlink-queue` / `nf-conntrack`

### 3. 空间优化
- **geoip 精简**：22.18MB → 0.23MB（`geoip-only-cn-private.dat`，只含 CN+PRIVATE）
- **squashfs 块 256K → 1M**：压缩率提升约 5%
- 去掉无 USB/SATA 机型用不到的存储栈（11 个包）

### 4. 内存 / 性能
- **zram + zstd**（比 lz4 多约 45% 有效容量），配 uci-defaults 强制生效
- **BBRv1** + `kmod-sched`（fq 队列）
- **HNAT + MTK WARP** 保留 —— honk 对直连流量有 direct offload，直连仍走硬件加速

### 5. 其他
- 去掉 `mtk-eqos`
- 加 `natmap` + LuCI

## 编译

推送到 `chasey-25.12-honk` 分支后，Actions 里手动触发 `Build H3C-NX30PRO (chasey 25.12 + honk)`。

工作流在 `make defconfig` 之后有一道**关键配置门禁**：如果 BTF、cgroups、honk 的 kmod 等被 defconfig 丢弃，会立刻报错而不是白编 3 小时。

## 刷机后

```sh
# 1) 导入 daeuniverse 源（只加 packages，不要加 kmods —— 自编内核用不了官方 BTF 包）
wget -O /etc/apk/keys/daeuniverse.pem https://openwrt.daeuniverse.org/public-key.pem
. /etc/openwrt_release
echo "@daeuniverse https://openwrt.daeuniverse.org/${DISTRIB_RELEASE%.*}/packages/$DISTRIB_ARCH/packages.adb" \
  > /etc/apk/repositories.d/daeuniverse.list
apk update

# 2) 装 honk（vmlinux-btf-builtin 会用内核自带 BTF 满足依赖）
apk add vmlinux-btf-builtin@daeuniverse
apk add honk@daeuniverse luci-app-honk@daeuniverse luci-i18n-daeuniverse-zh-cn@daeuniverse

# 3) 启用
uci set honk.config.enabled=1 && uci commit honk
/etc/init.d/honk enable && /etc/init.d/honk start
```

**升级只用定向方式**，别敲裸 `apk upgrade`（会把精简过的 geoip 换回 22MB 全量版）：

```sh
apk upgrade honk
```

## 验证

```sh
# 内核 BTF（honk 的启动前置）
ls -l /sys/kernel/btf/vmlinux

# zram 用的是不是 zstd
cat /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep '\['

# geoip 是否还是精简版（应为 0.23MB）
du -h /usr/share/v2ray/geoip.dat

# BBR
sysctl net.ipv4.tcp_congestion_control
```
