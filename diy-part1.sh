#!/bin/bash
#
# diy-part1.sh —— feeds update 之前执行
# 当前工作目录是 openwrt/
#
set -e

echo "==================== DIY part 1 开始 ===================="

# ---------------------------------------------------------------------------
# 1) 关掉「模块 BTF」
#
#    config/Config-kernel.in 里：
#        config KERNEL_DEBUG_INFO_BTF_MODULES
#                def_bool y                      <- 没有 prompt，.config 覆盖不了
#                depends on KERNEL_DEBUG_INFO_BTF
#
#    因为它是 def_bool（无菜单项），在 .config 里写 "# ... is not set" 会被
#    kconfig 直接忽略，照样按 y 处理 —— 于是几百个 .ko 每个都塞一份 BTF，
#    白占几百 KB 到 1 MB。这里直接改默认值。
#
#    honk 的 eBPF 只对内核核心结构体做 CO-RE（task_struct / sock / sk_buff），
#    全在 vmlinux 里，不需要任何模块 BTF。
# ---------------------------------------------------------------------------
CK="config/Config-kernel.in"
if [ -f "$CK" ]; then
	python3 - "$CK" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = "config KERNEL_DEBUG_INFO_BTF_MODULES\n\tdef_bool y\n"
new = "config KERNEL_DEBUG_INFO_BTF_MODULES\n\tdef_bool n\n"
if s.count(old) == 1:
    open(p, "w").write(s.replace(old, new))
    print("  ✓ 已把 KERNEL_DEBUG_INFO_BTF_MODULES 的默认值改为 n")
elif "config KERNEL_DEBUG_INFO_BTF_MODULES\n\tdef_bool n" in s:
    print("  - 已是 def_bool n，跳过")
else:
    print("  ! 未找到预期模式，保持原样（不影响编译，只是多占点空间）")
PYEOF
else
	echo "  ! 找不到 $CK"
fi

# 校验：顺便把 .config 里那条无效的 is not set 删掉，避免误导
sed -i '/^# CONFIG_KERNEL_DEBUG_INFO_BTF_MODULES is not set$/d' .config 2>/dev/null || true

echo "---- Config-kernel.in 中的实际结果 ----"
grep -A2 "^config KERNEL_DEBUG_INFO_BTF_MODULES" "$CK" 2>/dev/null || true

echo "---- feeds.conf.default ----"
cat feeds.conf.default 2>/dev/null || echo "  (不存在，将使用源码树默认)"

# 如果以后想追加 feed，在这里加，例如：
# echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default

echo "==================== DIY part 1 结束 ===================="
