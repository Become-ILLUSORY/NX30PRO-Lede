#!/bin/bash
#
# diy-part1.sh —— feeds update 之前执行
# 当前工作目录是 openwrt/
#
# 沿用源码树自带的 feeds.conf.default（chasey 的 5 个 feed）：
#   packages / luci        -> immortalwrt/packages|luci @ openwrt-25.12
#   routing / telephony / video -> openwrt/* @ openwrt-25.12
#
# honk 不编进固件（运行时从 openwrt.daeuniverse.org 的 apk 源安装），
# 所以这里不需要追加任何代理插件的 feed。
#

echo "==================== DIY part 1 开始 ===================="
echo "feeds.conf.default 内容："
cat feeds.conf.default 2>/dev/null || echo "  (不存在，将使用源码树默认)"

# 如果以后想追加 feed，在这里加，例如：
# echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default

echo "==================== DIY part 1 结束 ===================="
