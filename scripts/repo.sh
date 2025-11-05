#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加和管理OpenWrt/ImmortalWrt的第三方软件源
#   包括各种常用插件和工具的集成
#
# 使用方法:
#   ./repo.sh
#
# 作者: Mary
# 日期：20251104
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 包目录
PACKAGE_DIR="package"
# 小型包仓库目录
SMALL_PACKAGE_DIR="small"
# Feeds配置文件
FEEDS_CONF="feeds.conf.default"

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

log_step "开始执行 OpenWrt 第三方软件源集成"

# 检查是否在OpenWrt根目录
if [ ! -f "Makefile" ] || [ ! -d "scripts" ]; then
    log_error "当前目录不是OpenWrt根目录，请在OpenWrt根目录下运行此脚本"
    exit 1
fi

# 创建必要的目录
safe_mkdir "$PACKAGE_DIR"
safe_mkdir "$SMALL_PACKAGE_DIR"

# --- 添加第三方软件源 ---

# 1. 京东云雅典娜LED控制
log_info "添加京东云雅典娜LED控制插件"
if [ ! -d "$PACKAGE_DIR/luci-app-athena-led" ]; then
    git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led "$PACKAGE_DIR/luci-app-athena-led"
    check_status "克隆京东云雅典娜LED控制插件失败"
    
    # 设置执行权限
    chmod +x "$PACKAGE_DIR/luci-app-athena-led/root/etc/init.d/athena_led"
    chmod +x "$PACKAGE_DIR/luci-app-athena-led/root/usr/sbin/athena-led"
    log_success "京东云雅典娜LED控制插件添加完成"
else
    log_info "京东云雅典娜LED控制插件已存在，跳过"
fi

# 2. PassWall by xiaorouji
log_info "添加 PassWall 插件"
# 移除 openwrt feeds 自带的核心库
log_debug "移除 openwrt feeds 自带的核心库"
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

# 添加 PassWall 核心包
if [ ! -d "$PACKAGE_DIR/passwall-packages" ]; then
    git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages "$PACKAGE_DIR/passwall-packages"
    check_status "克隆 PassWall 核心包失败"
    log_success "PassWall 核心包添加完成"
else
    log_info "PassWall 核心包已存在，跳过"
fi

# 移除 openwrt feeds 过时的luci版本
log_debug "移除 openwrt feeds 过时的luci版本"
rm -rf feeds/luci/applications/luci-app-passwall

# 添加 PassWall LUCI 应用
if [ ! -d "$PACKAGE_DIR/passwall-luci" ]; then
    git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall "$PACKAGE_DIR/passwall-luci"
    check_status "克隆 PassWall LUCI 应用失败"
    log_success "PassWall LUCI 应用添加完成"
else
    log_info "PassWall LUCI 应用已存在，跳过"
fi

# 3. PassWall2 by xiaorouji
log_info "添加 PassWall2 插件"
if [ ! -d "$PACKAGE_DIR/passwall2-luci" ]; then
    git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 "$PACKAGE_DIR/passwall2-luci"
    check_status "克隆 PassWall2 插件失败"
    log_success "PassWall2 插件添加完成"
else
    log_info "PassWall2 插件已存在，跳过"
fi

# 4. AdGuardHome by sirpdboy
log_info "添加 AdGuardHome 插件"
if [ ! -d "$PACKAGE_DIR/luci-app-adguardhome" ]; then
    git clone --depth=1 https://github.com/sirpdboy/luci-app-adguardhome.git "$PACKAGE_DIR/luci-app-adguardhome"
    check_status "克隆 AdGuardHome 插件失败"
    log_success "AdGuardHome 插件添加完成"
else
    log_info "AdGuardHome 插件已存在，跳过"
fi

# 5. ddns-go by sirpdboy
log_info "添加 ddns-go 插件"
if [ ! -d "$PACKAGE_DIR/ddns-go" ]; then
    git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go.git "$PACKAGE_DIR/ddns-go"
    check_status "克隆 ddns-go 插件失败"
    log_success "ddns-go 插件添加完成"
else
    log_info "ddns-go 插件已存在，跳过"
fi

# 6. luci-app-netdata by sirpdboy
log_info "添加 netdata 监控插件"
if [ ! -d "$PACKAGE_DIR/luci-app-netdata" ]; then
    git clone --depth=1 https://github.com/sirpdboy/luci-app-netdata "$PACKAGE_DIR/luci-app-netdata"
    check_status "克隆 netdata 监控插件失败"
    log_success "netdata 监控插件添加完成"
else
    log_info "netdata 监控插件已存在，跳过"
fi

# 7. luci-app-netspeedtest by sirpdboy
log_info "添加 网速测试插件"
if [ ! -d "$PACKAGE_DIR/luci-app-netspeedtest" ]; then
    git clone https://github.com/sirpdboy/luci-app-netspeedtest "$PACKAGE_DIR/luci-app-netspeedtest"
    check_status "克隆 网速测试插件失败"
    log_success "网速测试插件添加完成"
else
    log_info "网速测试插件已存在，跳过"
fi

# 8. luci-app-partexp by sirpdboy
log_info "添加 分区管理插件"
if [ ! -d "$PACKAGE_DIR/luci-app-partexp" ]; then
    git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp.git "$PACKAGE_DIR/luci-app-partexp"
    check_status "克隆 分区管理插件失败"
    log_success "分区管理插件添加完成"
else
    log_info "分区管理插件已存在，跳过"
fi

# 9. luci-app-taskplan by sirpdboy
log_info "添加 任务计划插件"
if [ ! -d "$PACKAGE_DIR/luci-app-taskplan" ]; then
    git clone https://github.com/sirpdboy/luci-app-taskplan "$PACKAGE_DIR/luci-app-taskplan"
    check_status "克隆 任务计划插件失败"
    log_success "任务计划插件添加完成"
else
    log_info "任务计划插件已存在，跳过"
fi

# 10. lucky by gdy666
log_info "添加 Lucky 端口管理工具"
if [ ! -d "$PACKAGE_DIR/lucky" ]; then
    git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git "$PACKAGE_DIR/lucky"
    check_status "克隆 Lucky 端口管理工具失败"
    log_success "Lucky 端口管理工具添加完成"
else
    log_info "Lucky 端口管理工具已存在，跳过"
fi

# 11. luci-app-easytier
log_info "添加 EasyTier 插件"
if [ ! -d "$PACKAGE_DIR/luci-app-easytier" ]; then
    git clone https://github.com/EasyTier/luci-app-easytier.git "$PACKAGE_DIR/luci-app-easytier"
    check_status "克隆 EasyTier 插件失败"
    log_success "EasyTier 插件添加完成"
else
    log_info "EasyTier 插件已存在，跳过"
fi

# 12. homeproxy by VIKINGYFY
log_info "添加 HomeProxy 插件"
if [ ! -d "$PACKAGE_DIR/homeproxy" ]; then
    git clone --depth=1 https://github.com/VIKINGYFY/homeproxy "$PACKAGE_DIR/homeproxy"
    check_status "克隆 HomeProxy 插件失败"
    log_success "HomeProxy 插件添加完成"
    log_info "提示: 可以使用以下命令生成 HomeProxy 配置:"
    log_info "bash -c \"\$(curl -fsSl https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh)\""
else
    log_info "HomeProxy 插件已存在，跳过"
fi

# 13. golang & luci-app-openlist2 by sbwml
log_info "添加 Golang 语言支持"
if [ ! -d "feeds/packages/lang/golang" ]; then
    git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
    check_status "克隆 Golang 语言支持失败"
    log_success "Golang 语言支持添加完成"
else
    log_info "Golang 语言支持已存在，跳过"
fi

log_info "添加 OpenList2 插件"
if [ ! -d "$PACKAGE_DIR/openlist" ]; then
    git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 "$PACKAGE_DIR/openlist"
    check_status "克隆 OpenList2 插件失败"
    log_success "OpenList2 插件添加完成"
else
    log_info "OpenList2 插件已存在，跳过"
fi

# 14. luci-app-mosdns by sbwml
log_info "添加 MosDNS 插件"
if [ ! -d "$PACKAGE_DIR/mosdns" ]; then
    git clone -b v5 https://github.com/sbwml/luci-app-mosdns "$PACKAGE_DIR/mosdns"
    check_status "克隆 MosDNS 插件失败"
    log_success "MosDNS 插件添加完成"
else
    log_info "MosDNS 插件已存在，跳过"
fi

# 15. luci-app-quickfile by sbwml
log_info "添加 QuickFile 插件"
if [ ! -d "$PACKAGE_DIR/quickfile" ]; then
    git clone --depth=1 https://github.com/sbwml/luci-app-quickfile "$PACKAGE_DIR/quickfile"
    check_status "克隆 QuickFile 插件失败"
    log_success "QuickFile 插件添加完成"
else
    log_info "QuickFile 插件已存在，跳过"
fi

# 16. momo 和 nikki 透明代理
log_info "添加 Momo 透明代理插件"
if [ ! -d "$PACKAGE_DIR/luci-app-momo" ]; then
    git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo "$PACKAGE_DIR/luci-app-momo"
    check_status "克隆 Momo 透明代理插件失败"
    log_success "Momo 透明代理插件添加完成"
else
    log_info "Momo 透明代理插件已存在，跳过"
fi

log_info "添加 Nikki 透明代理插件"
if [ ! -d "$PACKAGE_DIR/luci-app-nikki" ]; then
    git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki "$PACKAGE_DIR/luci-app-nikki"
    check_status "克隆 Nikki 透明代理插件失败"
    log_success "Nikki 透明代理插件添加完成"
else
    log_info "Nikki 透明代理插件已存在，跳过"
fi

# 17. OpenAppFilter (OAF)
log_info "添加 OpenAppFilter 应用过滤插件"
if [ ! -d "$PACKAGE_DIR/OpenAppFilter" ]; then
    git clone https://github.com/destan19/OpenAppFilter.git "$PACKAGE_DIR/OpenAppFilter"
    check_status "克隆 OpenAppFilter 应用过滤插件失败"
    log_success "OpenAppFilter 应用过滤插件添加完成"
else
    log_info "OpenAppFilter 应用过滤插件已存在，跳过"
fi

# 18. luci-app-openclash by vernesong
log_info "添加 OpenClash 插件"
if [ ! -d "$PACKAGE_DIR/luci-app-openclash" ]; then
    git clone -b dev https://github.com/vernesong/OpenClash.git "$PACKAGE_DIR/luci-app-openclash"
    check_status "克隆 OpenClash 插件失败"
    log_success "OpenClash 插件添加完成"
else
    log_info "OpenClash 插件已存在，跳过"
fi

# 19. tailscale
log_info "添加 Tailscale 插件"
# 修改 Tailscale Makefile
if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
    log_debug "修改 Tailscale Makefile"
    sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
fi

if [ ! -d "$PACKAGE_DIR/luci-app-tailscale" ]; then
    git clone --depth=1 https://github.com/asvow/luci-app-tailscale "$PACKAGE_DIR/luci-app-tailscale"
    check_status "克隆 Tailscale 插件失败"
    log_success "Tailscale 插件添加完成"
else
    log_info "Tailscale 插件已存在，跳过"
fi

# 20. vnt
log_info "添加 VNT 插件"
if [ ! -d "$PACKAGE_DIR/luci-app-vnt" ]; then
    git clone https://github.com/lmq8267/luci-app-vnt.git "$PACKAGE_DIR/luci-app-vnt"
    check_status "克隆 VNT 插件失败"
    log_success "VNT 插件添加完成"
else
    log_info "VNT 插件已存在，跳过"
fi

# 21. kenzok8/small-package 后备仓库
log_info "添加 Small-Package 后备仓库"
if [ ! -d "$SMALL_PACKAGE_DIR" ]; then
    git clone --depth=1 https://github.com/kenzok8/small-package "$SMALL_PACKAGE_DIR"
    check_status "克隆 Small-Package 后备仓库失败"
    log_success "Small-Package 后备仓库添加完成"
else
    log_info "Small-Package 后备仓库已存在，跳过"
fi

# --- 更新 feeds ---
log_step "更新软件源"
./scripts/feeds update -a
check_status "更新软件源失败"

log_step "安装软件包"
./scripts/feeds install -a
check_status "安装软件包失败"

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)
generate_summary "OpenWrt 第三方软件源集成" "$SCRIPT_START_TIME" "$SCRIPT_END_TIME" "成功"

log_success "OpenWrt 第三方软件源集成完成"
