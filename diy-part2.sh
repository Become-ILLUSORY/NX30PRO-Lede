#!/bin/bash
#
# diy-part2.sh —— feeds install 之后、make defconfig 之前执行
# 当前工作目录是 openwrt/
#
# 本工作流不编译 geo：v2ray-geoip / v2ray-geosite 由独立的 geo-mini
# 工作流产成两个小 apk，刷机后手动安装。这里只把 feed 的全量包摘掉，
# 省得 make download 白拉 24 MB。
#
set -e

echo "==================== DIY part 2 开始 ===================="

# ---------------------------------------------------------------------------
# 1) 摘掉 feed 里的全量 geo 包
#
#    v2ray-geodata 的 Build/Prepare 会下载 geoip.dat(22 MB) + dlc.dat(2.4 MB)。
#    本固件不需要它们（geo 由 geo-mini 工作流单独产出），直接移除以省带宽。
#
#    对应的 .config 里：
#      # CONFIG_PACKAGE_v2ray-geoip is not set
#      # CONFIG_PACKAGE_v2ray-geosite is not set
# ---------------------------------------------------------------------------
GEO_FEED_DIR="feeds/packages/net/v2ray-geodata"
GEO_LINK_DIR="package/feeds/packages/v2ray-geodata"

if [ -d "$GEO_FEED_DIR" ] || [ -e "$GEO_LINK_DIR" ]; then
	rm -rf "$GEO_LINK_DIR" "$GEO_FEED_DIR"
	echo "  已移除 feed 的 v2ray-geodata（本固件不含 geo）"
else
	echo "  feed 里没有 v2ray-geodata，跳过"
fi

for pkg in v2ray-geoip v2ray-geosite; do
	sed -i "/^CONFIG_PACKAGE_${pkg}=y$/d" .config
	grep -qE "^# CONFIG_PACKAGE_${pkg} is not set$" .config || \
		echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
done
echo "  v2ray-geoip / v2ray-geosite → is not set"

# ---------------------------------------------------------------------------
# 2) 打开 ccache（配合 actions/cache，重复编译快很多）
# ---------------------------------------------------------------------------
if ! grep -q '^CONFIG_CCACHE=y' .config; then
	echo 'CONFIG_CCACHE=y' >> .config
	echo "  ✓ 已启用 ccache"
fi

# ---------------------------------------------------------------------------
# 3) 默认主机名 / 时区（可按需改）
# ---------------------------------------------------------------------------
sed -i "s/set system.@system\[-1\].hostname='OpenWrt'/set system.@system[-1].hostname='NX30Pro'/g" \
	package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i "s/set system.@system\[-1\].timezone='UTC'/set system.@system[-1].timezone='CST-8'/g" \
	package/base-files/files/bin/config_generate 2>/dev/null || true

echo "==================== DIY part 2 结束 ===================="
