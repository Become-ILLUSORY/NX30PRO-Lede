# NX30PRO-Lede

H3C Magic NX30 Pro 的 OpenWrt 云编译仓库。

[![Build](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/openwrt-builder.yml/badge.svg?branch=chasey-25.12-honk)](https://github.com/Become-ILLUSORY/NX30PRO-Lede/actions/workflows/openwrt-builder.yml)

| 项 | 值 |
|---|---|
| 硬件 | MT7981B（2×Cortex-A53 @1.3GHz）/ 256MB DDR / 128MB NAND |
| 源码树 | [`chasey-dev/immortalwrt-mt798x-rebase`](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) @ `25.12` |
| 内核 | **6.12**（honk 要求 6.12+） |
| 机型 | `h3c_magic-nx30-pro-mtkuboot`（MTK U-Boot layout） |
| 包管理 | **apk**（OpenWrt 25.12 起） |

---

## 分支

| 分支 | 源码树 | 内核 | 说明 |
|---|---|---|---|
| `padavanonly` | padavanonly/immortalwrt-mt798x-6.6 @ openwrt-24.10-6.6 | 6.6 | 历史版本，opkg |
| **`chasey-25.12-honk`** | **chasey-dev/immortalwrt-mt798x-rebase @ 25.12** | **6.12** | 当前，为 honk 准备 |

---

## 当前固件内容

- **代理**：不含任何代理内核。honk 从 [`openwrt.daeuniverse.org`](https://openwrt.daeuniverse.org/zh-cn/) 在线安装，可独立更新。
- **硬件加速**：HNAT（`kmod-mediatek_hnat`）+ MTK WARP（`kmod-warp`，含 MT7981 WOCPU 固件）+ turboacc
- **内存**：zram 用 **zstd**（容量约为 RAM 一半，等效 ~3×）
- **拥塞控制**：BBR v1 + `fq`（`kmod-sched`）
- **端口映射**：`natmap` + LuCI
- **Web**：LuCI + argon 主题

### 相对上游 defconfig 的改动

| 改动 | 说明 |
|---|---|
| 单机型 | 从 92 机型全家桶裁到只剩 `h3c_magic-nx30-pro-mtkuboot` |
| geoip 精简 | 22.18 MB → **0.23 MB**（`geoip-only-cn-private.dat`，仅 CN+PRIVATE） |
| squashfs 块 1 MiB | 默认 256 KiB，压缩率提升约 5% |
| 关闭模块 BTF | `KERNEL_DEBUG_INFO_BTF_MODULES` 改 `def_bool n`，不给几百个 `.ko` 生成 BTF 段 |
| 删无用包 | 无 USB/SATA 机型用不到的存储栈（11 个包） |
| 去掉 | `luci-app-eqos-mtk` / `mtkhqos_util` |

### 为 honk 准备的内核能力

honk 不编进固件，但它的内核前提必须内建：

```conf
CONFIG_KERNEL_DEBUG_INFO_BTF=y      # eBPF CO-RE 需要 /sys/kernel/btf/vmlinux
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_NETKIT=y
```

外加 `kernel-config-6.12.append` 追加：

```conf
CONFIG_CGROUP_BPF=y
CONFIG_SOCK_CGROUP_DATA=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_NETKIT=y
```

以及 7 个 kmod：`veth` / `sched-core` / `sched-bpf` / `nft-core` / `nft-queue` / `nfnetlink-queue` / `nf-conntrack`。

---

## 已验证的构建结果

最近一次成功构建：Release **`2026.10.29-0548`**

| 产物 | 大小 |
|---|---|
| `...-squashfs-factory.bin` | 19.25 MB |
| `...-squashfs-sysupgrade.bin` | 17.67 MB |
| `...-initramfs-kernel.bin` | 16.95 MB |

镜像内部实测（解包后核对，非推测）：

| 项 | 实测 |
|---|---|
| 包数量 | 260 |
| rootfs (squashfs) | 12.01 MB，**xz**，**块 1 MiB** |
| kernel | 5.65 MB |
| `usr/share/v2ray/geoip.dat` | **238,307 B（0.23 MB）** ← 精简版确认 |
| `lib/firmware/7981_WOCPU0_RAM_CODE_release.bin` | 2.45 MB ← WARP 芯片配置为 mt7981 |
| `mtk_warp.ko` / `mtk_warp_proxy.ko` | ✓ |
| `etc/uci-defaults/99-zram-zstd` | ✓ zram 开机自动用 zstd |

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

```sh
# 1) 导入公钥
wget -O /etc/apk/keys/daeuniverse.pem https://openwrt.daeuniverse.org/public-key.pem

# 2) 只加 packages 源；不要加 kmods 源（自编内核装不了官方 vmlinux-btf）
. /etc/openwrt_release
echo "@daeuniverse https://openwrt.daeuniverse.org/${DISTRIB_RELEASE%.*}/packages/$DISTRIB_ARCH/packages.adb" \
  > /etc/apk/repositories.d/daeuniverse.list
apk update

# 3) 先装 BTF 占位包 —— 这一步会验证内核 BTF 是否编对
apk add vmlinux-btf-builtin@daeuniverse

# 4) 装 honk
apk add honk@daeuniverse luci-app-honk@daeuniverse luci-i18n-daeuniverse-zh-cn@daeuniverse

# 5) 启用
uci set honk.config.enabled=1 && uci commit honk
/etc/init.d/honk enable && /etc/init.d/honk start
```

> `vmlinux-btf-builtin` 的 preinst 会检查 `/sys/kernel/btf/vmlinux`。装不上说明内核 BTF 没编进去。

---

## 刷完自检

```sh
ls -l /sys/kernel/btf/vmlinux                                  # 非空 = BTF 正常
cat /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep '\['  # 应为 [zstd]
du -h /usr/share/v2ray/geoip.dat                               # 应为 0.23M
sysctl net.ipv4.tcp_congestion_control                         # 应为 bbr
```

HNAT 需要在 LuCI 里手动打开（`turboacc` 默认关闭）。**honk 对直连流量有 direct offload，直连仍走硬件加速；只有走代理的流量受 CPU 限制。**

---

## ⚠️ 升级注意

**只用定向升级：**

```sh
apk upgrade honk
```

**不要敲裸 `apk upgrade`** —— 它会把精简过的 `v2ray-geoip` 换回 22 MB 全量版，overlay 瞬间被吃掉。

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

---

## 致谢

- [chasey-dev](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) —— MT798x 源码树与 MTK 补丁
- [padavanonly](https://github.com/padavanonly/immortalwrt-mt798x-6.6) —— HNAT 补丁栈
- [daeuniverse](https://github.com/daeuniverse/honk) —— honk / dae
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) —— 工作流模板
