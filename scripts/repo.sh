#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加和管理 OpenWrt/ImmortalWrt 的第三方软件源
#   预先检查并删除官方feeds中可能存在的同名软件包
#   使用 small-package 作为后备仓库
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：20251114
# 版本: 3.3 - 优化环境检查版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 软件源列表
declare -A REPOS=(
    ["luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led"
    ["luci-app-passwall2"]="https://github.com/xiaorouji/openwrt-passwall2"
    ["luci-app-adguardhome"]="https://github.com/sirpdboy/luci-app-adguardhome"
    ["luci-app-ddns-go"]="https://github.com/sirpdboy/luci-app-ddns-go"
    ["luci-app-netdata"]="https://github.com/sirpdboy/luci-app-netdata"
    ["luci-app-netspeedtest"]="https://github.com/sirpdboy/luci-app-netspeedtest"
    ["luci-app-partexp"]="https://github.com/sirpdboy/luci-app-partexp"
    ["luci-app-taskplan"]="https://github.com/sirpdboy/luci-app-taskplan"
    ["luci-app-lucky"]="https://github.com/gdy666/luci-app-lucky"
    ["luci-app-easytier"]="https://github.com/EasyTier/luci-app-easytier"
    ["luci-app-homeproxy"]="https://github.com/VIKINGYFY/homeproxy"
    ["packages_lang_golang"]="https://github.com/sbwml/packages_lang_golang -b 25.x"
    ["luci-app-openlist2"]="https://github.com/sbwml/luci-app-openlist2"
    ["luci-app-mosdns"]="https://github.com/sbwml/luci-app-mosdns -b v5"
    ["luci-app-quickfile"]="https://github.com/sbwml/luci-app-quickfile"
    ["luci-app-momo"]="https://github.com/nikkinikki-org/OpenWrt-momo"
    ["luci-app-nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki"
    ["luci-app-oaf"]="https://github.com/destan19/OpenAppFilter"
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash"
    ["luci-app-tailscale"]="https://github.com/asvow/luci-app-tailscale"
    ["luci-app-vnt"]="https://github.com/lmq8267/luci-app-vnt"
    ["small-package"]="https://github.com/kenzok8/small-package"
    # 缺失的软件包
    ["luci-app-istorex"]="https://github.com/istoreos/istore"
    ["luci-app-quickstart"]="https://github.com/kenzok8/small-package"
    ["luci-app-wolplus"]="https://github.com/kenzok8/small-package"
)

# 特殊处理列表
declare -A SPECIAL_HANDLING=(
    ["packages_lang_golang"]="feeds/packages/lang/golang"
    ["luci-app-tailscale"]="pre_remove_feeds"
    ["luci-app-mosdns"]="mosdns_special"
    ["luci-app-openclash"]="openclash_special"
    ["small-package"]="small"
)

# 可能冲突的软件包列表（不同名称但功能相同）
declare -A CONFLICTING_PACKAGES=(
    ["luci-app-lucky"]="luci-app-lucky-sirpdboy"
    ["luci-app-homeproxy"]="homeproxy"
    ["luci-app-openclash"]="luci-app-passwall2 luci-app-mosdns"
    ["luci-app-tailscale"]="tailscale"
    ["luci-app-vnt"]="vnt"
    ["luci-app-momo"]="sing-box"
    ["luci-app-nikki"]="mihomo"
    ["luci-app-oaf"]="openappfilter"
    ["luci-app-adguardhome"]="adguardhome"
    ["luci-app-passwall2"]="passwall2"
)

# 官方feeds中可能存在的软件包列表
declare -A FEEDS_PACKAGES=(
    ["luci-app-adguardhome"]="luci-app-adguardhome"
    ["luci-app-passwall2"]="luci-app-passwall2"
    ["luci-app-tailscale"]="tailscale luci-app-tailscale"
    ["luci-app-openclash"]="luci-app-openclash"
    ["luci-app-homeproxy"]="homeproxy"
    ["luci-app-momo"]="sing-box luci-app-momo"
    ["luci-app-nikki"]="mihomo luci-app-nikki"
    ["luci-app-oaf"]="openappfilter luci-app-oaf"
    ["luci-app-easytier"]="easytier luci-app-easytier"
    ["luci-app-vnt"]="vnt luci-app-vnt"
    ["luci-app-lucky"]="lucky luci-app-lucky"
    ["luci-app-quickfile"]="luci-app-quickfile"
    ["luci-app-quickstart"]="luci-app-quickstart"
    ["luci-app-istorex"]="luci-app-istorex"
    ["luci-app-netdata"]="luci-app-netdata"
    ["luci-app-netspeedtest"]="luci-app-netspeedtest"
    ["luci-app-partexp"]="luci-app-partexp"
    ["luci-app-taskplan"]="luci-app-taskplan"
    ["luci-app-ddns-go"]="ddns-go luci-app-ddns-go"
    ["luci-app-wolplus"]="luci-app-wolplus"
    ["luci-app-upnp"]="luci-app-upnp miniupnpd"
    ["luci-app-samba4"]="luci-app-samba4"
    ["luci-app-ttyd"]="ttyd luci-app-ttyd"
    ["luci-app-vlmcsd"]="vlmcsd luci-app-vlmcsd"
    ["luci-app-frpc"]="frpc luci-app-frpc"
    ["luci-app-frps"]="frps luci-app-frps"
    ["luci-app-openlist2"]="luci-app-openlist2"
    ["luci-app-mosdns"]="mosdns luci-app-mosdns"
)

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 3.3 - 优化环境检查版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查环境
check_environment() {
    log_info "检查执行环境..."
    
    # 使用通用环境检查
    check_openwrt_environment "full" || return 1
    
    # 检查网络连接（可跳过）
    if [ "${SKIP_NETWORK_CHECK:-0}" != "1" ]; then
        check_network || {
            log_error "网络连接异常，无法继续执行"
            log_info "提示: 可以设置 SKIP_NETWORK_CHECK=1 跳过网络检查"
            return 1
        }
    else
        log_warning "跳过网络检查（SKIP_NETWORK_CHECK=1）"
    fi
    
    # 检查磁盘空间
    check_disk_space "." 2 || {
        log_error "磁盘空间不足，至少需要2GB空间"
        return 1
    }
    
    log_success "环境检查通过"
}

# ... 其余函数保持不变 ...

# 主执行流程
main() {
    local start_time=$(date +%s)
    
    show_script_info
    
    if check_environment; then
        if process_repos; then
            generate_final_summary
        else
            generate_final_summary
            log_warning "部分仓库处理失败，但继续执行后续步骤"
        fi
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
    
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

main "$@"