#
# v2ray-geo-mini —— 极简 GeoIP/GeoSite 数据包
#
# 目的：替换官方 v2ray-geodata 提供的 24 MB 全量数据，用 0.9 MB 的
#      CN 精简版满足 honk 的包依赖，同时给 honk 手动/自动更新留一个种子。
#
# 为什么不能是空包：
#   honk 的 native_api/geodata.rs 里 updatable() 要求 assets 非空，
#   而自动更新和手动更新（POST /api/v1/geodata/update）共用同一个 queue()。
#   没有 geo 文件 → assets 为空 → 永远不下载，形成死锁。
#   所以必须放真实文件作为种子。
#
# 内容：
#   geoip.dat    238,307 B  只含 CN + PRIVATE
#   geosite.dat  704,703 B  只含 GEOLOCATION-CN / GEOLOCATION-!CN / CATEGORY-ADS-ALL
#
# 版本号必须大于官方的时间戳版本，否则 apk 会认为官方包更新并覆盖它。
# 官方两个包的版本位数不同（实测）：
#   v2ray-geoip    202610050438    12 位
#   v2ray-geosite  20261009101206  14 位
# apk 按数值比较，所以用 20 位最保险；12 位会被 geosite 判成 downgrade。

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-geo-mini
PKG_VERSION:=99999999999999999999
PKG_RELEASE:=1

PKG_LICENSE:=CC-BY-SA-4.0
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/v2ray-geoip
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=Minimal GeoIP list (CN + PRIVATE only, ~0.23 MB)
  URL:=https://github.com/v2fly/geoip
  PKGARCH:=all
  VERSION:=$(PKG_VERSION)-r$(PKG_RELEASE)
  LICENSE:=CC-BY-SA-4.0
  PROVIDES:=@v2ray-geodata @xray-geodata @xray-geoip
endef

define Package/v2ray-geosite
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=Minimal GeoSite list (CN / !CN / ads only, ~0.67 MB)
  URL:=https://github.com/v2fly/domain-list-community
  PKGARCH:=all
  VERSION:=$(PKG_VERSION)-r$(PKG_RELEASE)
  LICENSE:=MIT
  PROVIDES:=@v2ray-geodata @xray-geodata @xray-geosite
endef

define Package/v2ray-geoip/description
 Minimal GeoIP database for geoip: routing conditions.
 Contains only CN and PRIVATE entries (~0.23 MB installed).
 honk keeps it fresh through its own geodata updater; configure
 assets.geodata.geoip in /etc/honk/config.dae to point at a
 non-redirecting mirror, since honk refuses HTTP redirects.
endef

define Package/v2ray-geosite/description
 Minimal GeoSite database for geosite: routing conditions.
 Contains only GEOLOCATION-CN, GEOLOCATION-!CN and CATEGORY-ADS-ALL
 (~0.67 MB installed). Other categories log a warning and expand to
 zero matchers, so add them to the build if your rules need them.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/v2ray-geoip/install
	# 和官方 v2ray-geodata 保持一致：只装到 /usr/share/v2ray 并软链到 xray。
	# /usr/share/honk/ 那个软链由 honk 包自己安装时创建，这里不能重复，
	# 否则 apk 会报 "trying to overwrite file owned by ..."。
	$(INSTALL_DIR) $(1)/usr/share/v2ray $(1)/usr/share/xray
	$(INSTALL_DATA) ./files/geoip.dat $(1)/usr/share/v2ray/geoip.dat
	$(LN) ../v2ray/geoip.dat $(1)/usr/share/xray/geoip.dat
endef

define Package/v2ray-geosite/install
	$(INSTALL_DIR) $(1)/usr/share/v2ray $(1)/usr/share/xray
	$(INSTALL_DATA) ./files/geosite.dat $(1)/usr/share/v2ray/geosite.dat
	$(LN) ../v2ray/geosite.dat $(1)/usr/share/xray/geosite.dat
endef

$(eval $(call BuildPackage,v2ray-geoip))
$(eval $(call BuildPackage,v2ray-geosite))
