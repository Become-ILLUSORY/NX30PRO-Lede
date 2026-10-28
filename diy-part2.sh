#!/bin/bash
#
# diy-part2.sh —— feeds install 之后、make defconfig 之前执行
# 当前工作目录是 openwrt/
#
set -e

echo "==================== DIY part 2 开始 ===================="

# ---------------------------------------------------------------------------
# 1) geoip 精简：22.18 MB 的全量 geoip.dat -> 0.23 MB 的 geoip-only-cn-private.dat
#
#    只保留 CN + PRIVATE 两个国家段（顶层条目 2 个 vs 全量 253 个）。
#    固件压缩后约省 4 MB。
#
#    注意：精简版没有别的国家段。如果你的规则里写了 GEOIP,US / GEOIP,JP
#          之类的，需要把这里注释掉。
# ---------------------------------------------------------------------------
GEO_MK="feeds/packages/net/v2ray-geodata/Makefile"
if [ -f "$GEO_MK" ]; then
	echo "---- 应用 geoip 精简补丁 ----"
	cp "$GEO_MK" "$GEO_MK.orig"
	sed -i 's|^GEOIP_FILE:=geoip\.dat\.\$(GEOIP_VER)$|GEOIP_FILE:=geoip-cn.dat.$(GEOIP_VER)|' "$GEO_MK"
	sed -i 's|^  URL_FILE:=geoip\.dat$|  URL_FILE:=geoip-only-cn-private.dat|' "$GEO_MK"
	sed -i 's|^  HASH:=4ff4b2ec242a9e87b296ba27ddb85f8311e8d3e071eaebac5be9231c60e408dd$|  HASH:=989cc8badc2ea6f7f1c1a2e70dbfd944658579c35589c07b4feff77421316c72|' "$GEO_MK"

	if grep -q "geoip-only-cn-private.dat" "$GEO_MK" && \
	   grep -q "989cc8badc2ea6f7f1c1a2e70dbfd944658579c35589c07b4feff77421316c72" "$GEO_MK"; then
		echo "  ✓ geoip 已改为精简版"
		grep -nE "GEOIP_FILE|URL_FILE|HASH" "$GEO_MK" | head -4
	else
		echo "  ✗ 补丁未生效，回滚"
		cp "$GEO_MK.orig" "$GEO_MK"
		exit 1
	fi
else
	echo "  ! 未找到 $GEO_MK，跳过 geoip 精简"
fi

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
