# scripts/repo.sh
#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   集成第三方软件源到OpenWrt构建系统
#   预先检查并删除官方feeds中可能存在的同名软件包
#   使用small-package作为后备仓库
#
# 使用方法:
#   ./repo.sh [OpenWrt根目录]
#
# 作者: Mary
# 日期：20251104
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 是否使用small-package作为后备仓库
USE_SMALL_PACKAGE=true
# 是否清理旧的软件包
CLEAN_OLD_PACKAGES=true
# 是否更新feeds
UPDATE_FEEDS=true
# 是否安装feeds
INSTALL_FEEDS=true

# --- 脚本逻辑 ---
OPENWRT_ROOT_DIR="$1"

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

log_step "开始集成第三方软件源"

# 显示系统资源使用情况
show_system_resources

# 检查参数
if [ -z "$OPENWRT_ROOT_DIR" ]; then
    OPENWRT_ROOT_DIR="."
    log_info "未指定OpenWrt根目录，使用当前目录"
fi

# 检查目录是否存在
check_dir_exists "$OPENWRT_ROOT_DIR" "OpenWrt 根目录不存在: $OPENWRT_ROOT_DIR"

# 检查OpenWrt环境
check_openwrt_env "$OPENWRT_ROOT_DIR"

# 切换到OpenWrt根目录
cd "$OPENWRT_ROOT_DIR" || exit 1

# 创建package目录（如果不存在）
safe_mkdir "package"

# 定义要添加的软件源列表
declare -A REPOSITORIES=(
    # 京东云雅典娜led控制
    ["luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led"
    
    # passwall by xiaorouji
    ["passwall-packages"]="https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages"
    ["luci-app-passwall"]="https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall"
    ["luci-app-passwall2"]="https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2"
    
    # AdGuardHome
    ["luci-app-adguardhome"]="https://github.com/sirpdboy/luci-app-adguardhome.git package/luci-app-adguardhome"
    
    # ddns-go
    ["luci-app-ddns-go"]="https://github.com/sirpdboy/luci-app-ddns-go.git package/luci-app-ddns-go"
    
    # netdata
    ["luci-app-netdata"]="https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata"
    
    # netspeedtest
    ["luci-app-netspeedtest"]="https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest"
    
    # partexp
    ["luci-app-partexp"]="https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp"
    
    # taskplan
    ["luci-app-taskplan"]="https://github.com/sirpdboy/luci-app-taskplan package/luci-app-taskplan"
    
    # lucky
    ["luci-app-lucky"]="https://github.com/gdy666/luci-app-lucky.git package/luci-app-lucky"
    
    # easytier
    ["luci-app-easytier"]="https://github.com/EasyTier/luci-app-easytier.git package/luci-app-easytier"
    
    # homeproxy
    ["homeproxy"]="https://github.com/VIKINGYFY/homeproxy package/homeproxy"
    
    # golang & openlist2
    ["packages_lang_golang"]="https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang"
    ["luci-app-openlist2"]="https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2"
    
    # mosdns
    ["luci-app-mosdns"]="https://github.com/sbwml/luci-app-mosdns -b v5 package/luci-app-mosdns"
    
    # quickfile
    ["luci-app-quickfile"]="https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile"
    
    # momo & nikki
    ["luci-app-momo"]="https://github.com/nikkinikki-org/OpenWrt-momo package/luci-app-momo"
    ["luci-app-nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki"
    
    # OpenAppFilter
    ["luci-app-oaf"]="https://github.com/destan19/OpenAppFilter.git package/luci-app-oaf"
    
    # openclash
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash.git -b dev package/luci-app-openclash"
    
    # tailscale
    ["luci-app-tailscale"]="https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale"
    
    # vnt
    ["luci-app-vnt"]="https://github.com/lmq8267/luci-app-vnt.git package/luci-app-vnt"
    
    # small-package
    ["small-package"]="https://github.com/kenzok8/small-package small"
)

# 定义需要从官方feeds中删除的软件包列表
declare -a OFFICIAL_PACKAGES_TO_REMOVE=(
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
    "geoview"
    "shadow-tls"
)

# 清理旧的软件包
if [ "$CLEAN_OLD_PACKAGES" = "true" ]; then
    log_substep "清理旧的软件包..."
    
    # 删除官方feeds中的特定软件包
    for package in "${OFFICIAL_PACKAGES_TO_REMOVE[@]}"; do
        if [ -d "feeds/packages/net/$package" ]; then
            log_info "删除官方feeds中的软件包: $package"
            safe_remove "feeds/packages/net/$package" true
        fi
    done
    
    # 删除旧的luci-app-passwall
    if [ -d "feeds/luci/applications/luci-app-passwall" ]; then
        log_info "删除旧的luci-app-passwall"
        safe_remove "feeds/luci/applications/luci-app-passwall" true
    fi
    
    # 删除旧的tailscale配置
    if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
        log_info "修改tailscale Makefile以避免冲突"
        sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
    fi
fi

# 克隆第三方软件源
log_substep "克隆第三方软件源..."
for repo_name in "${!REPOSITORIES[@]}"; do
    repo_info="${REPOSITORIES[$repo_name]}"
    repo_url=$(echo "$repo_info" | awk '{print $1}')
    repo_path=$(echo "$repo_info" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
    
    log_info "克隆仓库: $repo_name"
    log_debug "URL: $repo_url"
    log_debug "路径: $repo_path"
    
    # 检查目标目录是否已存在
    target_dir=$(echo "$repo_path" | awk '{print $1}')
    if [ -d "$target_dir" ]; then
        log_info "目标目录已存在，跳过: $target_dir"
        continue
    fi
    
    # 执行克隆命令
    if git clone $repo_url $repo_path; then
        log_success "成功克隆: $repo_name"
        
        # 特殊处理
        case "$repo_name" in
            "luci-app-athena-led")
                log_info "设置athena-led权限..."
                chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
                ;;
        esac
    else
        log_error "克隆失败: $repo_name"
    fi
done

# 更新feeds
if [ "$UPDATE_FEEDS" = "true" ]; then
    log_substep "更新feeds..."
    if ./scripts/feeds update -a; then
        log_success "Feeds更新成功"
    else
        log_error "Feeds更新失败"
        exit 1
    fi
fi

# 安装feeds
if [ "$INSTALL_FEEDS" = "true" ]; then
    log_substep "安装feeds..."
    if ./scripts/feeds install -a; then
        log_success "Feeds安装成功"
    else
        log_error "Feeds安装失败"
        exit 1
    fi
fi

# 显示当前磁盘使用情况
log_info "当前磁盘使用情况:"
df -h

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)
generate_summary "第三方软件源集成" "$SCRIPT_START_TIME" "$SCRIPT_END_TIME" "成功"

log_success "第三方软件源集成完成。"
