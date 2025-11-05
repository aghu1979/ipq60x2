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

# --- 需要检查删除的官方Feeds软件包名称列表 ---
# 这些软件包可能与第三方源冲突，需要检查并删除官方版本
PKG_LIST=(
    "lucky"
    "luci-app-lucky"
    "homeproxy"
    "luci-app-homeproxy"
    "nikki"
    "luci-app-nikki"
    "momo"
    "luci-app-momo"
    "adguardhome"
    "luci-app-adguardhome"
    "ddns-go"
    "luci-app-ddns-go"
    "netdata"
    "luci-app-netdata"
    "netspeedtest"
    "luci-app-netspeedtest"
    "partexp"
    "luci-app-partexp"
    "taskplan"
    "luci-app-taskplan"
    "easytier"
    "luci-app-easytier"
    "openlist2"
    "luci-app-openlist2"
    "mosdns"
    "luci-app-mosdns"
    "quickfile"
    "luci-app-quickfile"
    "OpenAppFilter"
    "luci-app-oaf"
    "openclash"
    "luci-app-openclash"
    "tailscale"
    "luci-app-tailscale"
    "vnt"
    "luci-app-vnt"
    "athena-led"
    "luci-app-athena-led"
    "passwall"
    "luci-app-passwall"
    "passwall2"
    "luci-app-passwall2"
)

# --- PassWall 相关依赖包列表 ---
# 这些是 PassWall 的依赖包，需要删除官方版本
PASSWALL_DEPS=(
    "xray-core"
    "v2ray-geodata"
    "sing-box"
    "chinadns-ng"
    "dns2socks"
    "hysteria"
    "ipt2socks"
    "microsocks"
    "naiveproxy"
    "shadowsocks-libev"
    "shadowsocks-rust"
    "shadowsocksr-libev"
    "simple-obfs"
    "tcping"
    "trojan-plus"
    "tuic-client"
    "v2ray-plugin"
    "xray-plugin"
    "geoview"
    "shadow-tls"
)

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

# 初始化统计变量
TOTAL_PACKAGES=0
SUCCESS_PACKAGES=0
FAILED_PACKAGES=0
FAILED_PACKAGE_LIST=""

log_step "开始执行 OpenWrt 第三方软件源集成"

# 检查是否在OpenWrt根目录
if [ ! -f "Makefile" ] || [ ! -d "scripts" ]; then
    log_error "当前目录不是OpenWrt根目录，请在OpenWrt根目录下运行此脚本"
    exit 1
fi

# 创建必要的目录
safe_mkdir "$PACKAGE_DIR"
safe_mkdir "$SMALL_PACKAGE_DIR"

# --- 预处理：删除可能冲突的官方软件包 ---
log_step "预处理：删除可能冲突的官方软件包"

# 删除本地可能存在的不同名称的软件包
for NAME in "${PKG_LIST[@]}"; do
    # 查找匹配的目录
    log_info "搜索目录: $NAME"
    FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

    # 删除找到的目录
    if [ -n "$FOUND_DIRS" ]; then
        while read -r DIR; do
            log_info "删除目录: $DIR"
            rm -rf "$DIR"
        done <<< "$FOUND_DIRS"
    else
        log_debug "未找到目录: $NAME"
    fi
done

log_success "预处理完成，已删除可能冲突的官方软件包"

# --- 添加第三方软件源 ---

# 1. 京东云雅典娜LED控制
log_info "添加京东云雅典娜LED控制插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-athena-led" ]; then
    if git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led "$PACKAGE_DIR/luci-app-athena-led"; then
        # 设置执行权限
        chmod +x "$PACKAGE_DIR/luci-app-athena-led/root/etc/init.d/athena_led"
        chmod +x "$PACKAGE_DIR/luci-app-athena-led/root/usr/sbin/athena-led"
        log_success "京东云雅典娜LED控制插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆京东云雅典娜LED控制插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-athena-led"
    fi
else
    log_info "京东云雅典娜LED控制插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 2. PassWall by xiaorouji
log_info "添加 PassWall 插件"

# 删除 PassWall 相关的官方依赖包
log_debug "删除 PassWall 相关的官方依赖包"
for NAME in "${PASSWALL_DEPS[@]}"; do
    # 查找匹配的目录
    log_debug "搜索 PassWall 依赖目录: $NAME"
    FOUND_DIRS=$(find ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

    # 删除找到的目录
    if [ -n "$FOUND_DIRS" ]; then
        while read -r DIR; do
            log_debug "删除 PassWall 依赖目录: $DIR"
            rm -rf "$DIR"
        done <<< "$FOUND_DIRS"
    else
        log_debug "未找到 PassWall 依赖目录: $NAME"
    fi
done

# 添加 PassWall 核心包
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/passwall-packages" ]; then
    if git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages "$PACKAGE_DIR/passwall-packages"; then
        log_success "PassWall 核心包添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 PassWall 核心包失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST passwall-packages"
    fi
else
    log_info "PassWall 核心包已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 添加 PassWall LUCI 应用
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/passwall-luci" ]; then
    if git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall "$PACKAGE_DIR/passwall-luci"; then
        log_success "PassWall LUCI 应用添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 PassWall LUCI 应用失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST passwall-luci"
    fi
else
    log_info "PassWall LUCI 应用已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 3. PassWall2 by xiaorouji
log_info "添加 PassWall2 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/passwall2-luci" ]; then
    if git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 "$PACKAGE_DIR/passwall2-luci"; then
        log_success "PassWall2 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 PassWall2 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST passwall2-luci"
    fi
else
    log_info "PassWall2 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 4. AdGuardHome by sirpdboy
log_info "添加 AdGuardHome 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-adguardhome" ]; then
    if git clone --depth=1 https://github.com/sirpdboy/luci-app-adguardhome.git "$PACKAGE_DIR/luci-app-adguardhome"; then
        log_success "AdGuardHome 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 AdGuardHome 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-adguardhome"
    fi
else
    log_info "AdGuardHome 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 5. ddns-go by sirpdboy
log_info "添加 ddns-go 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/ddns-go" ]; then
    if git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go.git "$PACKAGE_DIR/ddns-go"; then
        log_success "ddns-go 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 ddns-go 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST ddns-go"
    fi
else
    log_info "ddns-go 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 6. luci-app-netdata by sirpdboy
log_info "添加 netdata 监控插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-netdata" ]; then
    if git clone --depth=1 https://github.com/sirpdboy/luci-app-netdata "$PACKAGE_DIR/luci-app-netdata"; then
        log_success "netdata 监控插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 netdata 监控插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-netdata"
    fi
else
    log_info "netdata 监控插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 7. luci-app-netspeedtest by sirpdboy
log_info "添加 网速测试插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-netspeedtest" ]; then
    if git clone https://github.com/sirpdboy/luci-app-netspeedtest "$PACKAGE_DIR/luci-app-netspeedtest"; then
        log_success "网速测试插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 网速测试插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-netspeedtest"
    fi
else
    log_info "网速测试插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 8. luci-app-partexp by sirpdboy
log_info "添加 分区管理插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-partexp" ]; then
    if git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp.git "$PACKAGE_DIR/luci-app-partexp"; then
        log_success "分区管理插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 分区管理插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-partexp"
    fi
else
    log_info "分区管理插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 9. luci-app-taskplan by sirpdboy
log_info "添加 任务计划插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-taskplan" ]; then
    if git clone https://github.com/sirpdboy/luci-app-taskplan "$PACKAGE_DIR/luci-app-taskplan"; then
        log_success "任务计划插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 任务计划插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-taskplan"
    fi
else
    log_info "任务计划插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 10. lucky by gdy666
log_info "添加 Lucky 端口管理工具"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/lucky" ]; then
    if git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git "$PACKAGE_DIR/lucky"; then
        log_success "Lucky 端口管理工具添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Lucky 端口管理工具失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST lucky"
    fi
else
    log_info "Lucky 端口管理工具已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 11. luci-app-easytier
log_info "添加 EasyTier 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-easytier" ]; then
    if git clone https://github.com/EasyTier/luci-app-easytier.git "$PACKAGE_DIR/luci-app-easytier"; then
        log_success "EasyTier 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 EasyTier 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-easytier"
    fi
else
    log_info "EasyTier 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 12. homeproxy by VIKINGYFY
log_info "添加 HomeProxy 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/homeproxy" ]; then
    if git clone --depth=1 https://github.com/VIKINGYFY/homeproxy "$PACKAGE_DIR/homeproxy"; then
        log_success "HomeProxy 插件添加完成"
        log_info "提示: 可以使用以下命令生成 HomeProxy 配置:"
        log_info "bash -c \"\$(curl -fsSl https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh)\""
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 HomeProxy 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST homeproxy"
    fi
else
    log_info "HomeProxy 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 13. golang & luci-app-openlist2 by sbwml
log_info "添加 Golang 语言支持"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "feeds/packages/lang/golang" ]; then
    if git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang; then
        log_success "Golang 语言支持添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Golang 语言支持失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST golang"
    fi
else
    log_info "Golang 语言支持已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

log_info "添加 OpenList2 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/openlist" ]; then
    if git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 "$PACKAGE_DIR/openlist"; then
        log_success "OpenList2 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 OpenList2 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST openlist"
    fi
else
    log_info "OpenList2 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 14. luci-app-mosdns by sbwml
log_info "添加 MosDNS 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/mosdns" ]; then
    if git clone -b v5 https://github.com/sbwml/luci-app-mosdns "$PACKAGE_DIR/mosdns"; then
        log_success "MosDNS 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 MosDNS 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST mosdns"
    fi
else
    log_info "MosDNS 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 15. luci-app-quickfile by sbwml
log_info "添加 QuickFile 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/quickfile" ]; then
    if git clone --depth=1 https://github.com/sbwml/luci-app-quickfile "$PACKAGE_DIR/quickfile"; then
        log_success "QuickFile 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 QuickFile 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST quickfile"
    fi
else
    log_info "QuickFile 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 16. momo 和 nikki 透明代理
log_info "添加 Momo 透明代理插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-momo" ]; then
    if git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo "$PACKAGE_DIR/luci-app-momo"; then
        log_success "Momo 透明代理插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Momo 透明代理插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-momo"
    fi
else
    log_info "Momo 透明代理插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

log_info "添加 Nikki 透明代理插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-nikki" ]; then
    if git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki "$PACKAGE_DIR/luci-app-nikki"; then
        log_success "Nikki 透明代理插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Nikki 透明代理插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-nikki"
    fi
else
    log_info "Nikki 透明代理插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 17. OpenAppFilter (OAF)
log_info "添加 OpenAppFilter 应用过滤插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/OpenAppFilter" ]; then
    if git clone https://github.com/destan19/OpenAppFilter.git "$PACKAGE_DIR/OpenAppFilter"; then
        log_success "OpenAppFilter 应用过滤插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 OpenAppFilter 应用过滤插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST OpenAppFilter"
    fi
else
    log_info "OpenAppFilter 应用过滤插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 18. luci-app-openclash by vernesong
log_info "添加 OpenClash 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-openclash" ]; then
    if git clone -b dev https://github.com/vernesong/OpenClash.git "$PACKAGE_DIR/luci-app-openclash"; then
        log_success "OpenClash 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 OpenClash 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-openclash"
    fi
else
    log_info "OpenClash 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 19. tailscale
log_info "添加 Tailscale 插件"
# 修改 Tailscale Makefile
if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
    log_debug "修改 Tailscale Makefile"
    sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
fi

TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-tailscale" ]; then
    if git clone --depth=1 https://github.com/asvow/luci-app-tailscale "$PACKAGE_DIR/luci-app-tailscale"; then
        log_success "Tailscale 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Tailscale 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-tailscale"
    fi
else
    log_info "Tailscale 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 20. vnt
log_info "添加 VNT 插件"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$PACKAGE_DIR/luci-app-vnt" ]; then
    if git clone https://github.com/lmq8267/luci-app-vnt.git "$PACKAGE_DIR/luci-app-vnt"; then
        log_success "VNT 插件添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 VNT 插件失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST luci-app-vnt"
    fi
else
    log_info "VNT 插件已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 21. kenzok8/small-package 后备仓库
log_info "添加 Small-Package 后备仓库"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$SMALL_PACKAGE_DIR" ]; then
    if git clone --depth=1 https://github.com/kenzok8/small-package "$SMALL_PACKAGE_DIR"; then
        log_success "Small-Package 后备仓库添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    else
        log_error "克隆 Small-Package 后备仓库失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST small-package"
    fi
else
    log_info "Small-Package 后备仓库已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# --- 更新 feeds ---
log_step "更新软件源"
if ./scripts/feeds update -a; then
    log_success "软件源更新成功"
else
    log_error "软件源更新失败"
    exit 1
fi

log_step "安装软件包"
if ./scripts/feeds install -a; then
    log_success "软件包安装成功"
else
    log_error "软件包安装失败"
    exit 1
fi

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)

# 输出详细摘要
echo -e "\n${CYAN}========== OpenWrt 第三方软件源集成 摘要 ==========${NC}"
echo -e "状态: ${GREEN}成功${NC}"
echo -e "总软件包数: ${TOTAL_PACKAGES}"
echo -e "成功添加: ${GREEN}${SUCCESS_PACKAGES}${NC}"
echo -e "添加失败: ${RED}${FAILED_PACKAGES}${NC}"

if [ $FAILED_PACKAGES -gt 0 ]; then
    echo -e "失败软件包列表: ${RED}${FAILED_PACKAGE_LIST}${NC}"
fi

echo -e "开始时间: $(date -d @$SCRIPT_START_TIME '+%Y-%m-%d %H:%M:%S')"
echo -e "结束时间: $(date -d @$SCRIPT_END_TIME '+%Y-%m-%d %H:%M:%S')"

DURATION=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))
echo -e "耗时: ${MINUTES}分${SECONDS}秒"
echo -e "${CYAN}=============================================${NC}\n"

log_success "OpenWrt 第三方软件源集成完成"
