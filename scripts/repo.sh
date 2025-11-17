#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加第三方软件源
#   检查并删除官方feeds中可能存在的不同名称的软件包
#   使用kenzok8/small-package作为后备仓库
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 3.3 - 优化环境检查版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 颜色定义 ---
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_RESET='\033[0m'

# --- 图标定义 ---
ICON_INFO="ℹ️"
ICON_SUCCESS="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"
ICON_PROCESSING="⏳"

# --- 日志函数 ---
log_info() {
    echo -e "${COLOR_BLUE}${ICON_INFO} [INFO] $1${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}${ICON_SUCCESS} [SUCCESS] $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}${ICON_WARNING} [WARNING] $1${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}${ICON_ERROR} [ERROR] $1${COLOR_RESET}"
}

log_processing() {
    echo -e "${COLOR_PURPLE}${ICON_PROCESSING} [PROCESSING] $1${COLOR_RESET}"
}

log_step() {
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN} $1${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
}

# --- 统计变量 ---
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0

# --- 软件源配置 ---

# 基础软件源配置
declare -A REPOS=(
    ["luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led"
    ["luci-app-adguardhome"]="https://github.com/sirpdboy/luci-app-adguardhome"
    ["luci-app-ddns-go"]="https://github.com/sirpdboy/luci-app-ddns-go"
    ["luci-app-netdata"]="https://github.com/sirpdboy/luci-app-netdata"
    ["luci-app-netspeedtest"]="https://github.com/sirpdboy/luci-app-netspeedtest"
    ["luci-app-partexp"]="https://github.com/sirpdboy/luci-app-partexp"
    ["luci-app-taskplan"]="https://github.com/sirpdboy/luci-app-taskplan"
    ["luci-app-lucky"]="https://github.com/gdy666/luci-app-lucky"
    ["luci-app-easytier"]="https://github.com/EasyTier/luci-app-easytier"
    ["luci-app-homeproxy"]="https://github.com/VIKINGYFY/homeproxy"
    ["luci-app-openlist2"]="https://github.com/sbwml/luci-app-openlist2"
    ["luci-app-quickfile"]="https://github.com/sbwml/luci-app-quickfile"
    ["luci-app-oaf"]="https://github.com/destan19/OpenAppFilter"
    ["luci-app-tailscale"]="https://github.com/asvow/luci-app-tailscale"
    ["luci-app-vnt"]="https://github.com/lmq8267/luci-app-vnt"
    ["small-package"]="https://github.com/kenzok8/small-package"
)

# 带分支的软件源配置
declare -A REPOS_WITH_BRANCH=(
    ["packages_lang_golang"]="https://github.com/sbwml/packages_lang_golang|25.x"
    ["luci-app-mosdns"]="https://github.com/sbwml/luci-app-mosdns|v5"
    ["luci-app-passwall2"]="https://github.com/xiaorouji/openwrt-passwall2|main"
)

# 需要添加到feeds.conf.default的软件源
declare -A FEED_SOURCES=(
    ["passwall_packages"]="https://github.com/xiaorouji/openwrt-passwall-packages|main"
    ["passwall_luci"]="https://github.com/xiaorouji/openwrt-passwall|main"
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash"
    ["momo"]="https://github.com/nikkinikki-org/OpenWrt-momo|main"
    ["nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki|main"
)

# 特殊处理配置
declare -A SPECIAL_HANDLING=(
    ["packages_lang_golang"]="feeds/packages/lang/golang"
    ["luci-app-tailscale"]="pre_remove_feeds"
    ["luci-app-mosdns"]="mosdns_special"
    ["luci-app-openclash"]="openclash_special"
    ["small-package"]="small"
)

# 可能冲突的软件包列表
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

# --- 函数定义 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 3.3 - 优化环境检查版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
}

# 检查环境
check_environment() {
    log_processing "检查执行环境..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    # 检查网络连接（可跳过）
    if [ "${SKIP_NETWORK_CHECK:-0}" != "1" ]; then
        if ! curl -s --connect-timeout 5 https://github.com > /dev/null; then
            log_error "网络连接异常，无法继续执行"
            log_info "提示: 可以设置 SKIP_NETWORK_CHECK=1 跳过网络检查"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    else
        log_warning "跳过网络检查（SKIP_NETWORK_CHECK=1）"
    fi
    
    # 检查磁盘空间
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "磁盘空间不足，至少需要2GB空间"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    log_success "环境检查通过"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 克隆仓库
clone_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local target_dir="$3"
    local branch="${4:-}"
    
    log_processing "正在克隆 $repo_name"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        log_info "目标目录已存在，删除旧目录: $target_dir"
        rm -rf "$target_dir"
    fi
    
    # 克隆仓库
    if [ -n "$branch" ]; then
        if git clone -b "$branch" "$repo_url" "$target_dir"; then
            log_success "克隆成功: $repo_name ($branch)"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $repo_name ($branch)"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    else
        if git clone "$repo_url" "$target_dir"; then
            log_success "克隆成功: $repo_name"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $repo_name"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    fi
}

# 添加软件源到feeds.conf.default
add_feed() {
    local feed_name="$1"
    local feed_url="$2"
    local feed_branch="${3:-}"
    
    log_processing "添加软件源: $feed_name"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 构建软件源条目
    local feed_entry="src-git $feed_name $feed_url"
    if [ -n "$feed_branch" ]; then
        feed_entry="$feed_entry;$feed_branch"
    fi
    
    # 检查是否已存在相同的软件源
    if grep -qF "$feed_entry" feeds.conf.default; then
        log_warning "软件源已存在，跳过添加: $feed_name"
        WARNING_COUNT=$((WARNING_COUNT + 1))
        return 1
    fi
    
    # 备份原文件
    cp feeds.conf.default feeds.conf.default.bak
    
    # 添加软件源
    if echo "$feed_entry" >> feeds.conf.default; then
        log_success "添加软件源成功: $feed_name"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log_error "添加软件源失败: $feed_name"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        # 恢复备份
        mv feeds.conf.default.bak feeds.conf.default
        return 1
    fi
}

# 处理基础仓库
process_basic_repos() {
    log_processing "处理基础仓库"
    
    for repo_name in "${!REPOS[@]}"; do
        local repo_url="${REPOS[$repo_name]}"
        local target_dir="package/$repo_name"
        
        clone_repo "$repo_name" "$repo_url" "$target_dir"
        
        # 特殊处理
        case "$repo_name" in
            "luci-app-athena-led")
                if [ -d "$target_dir" ]; then
                    chmod +x "$target_dir/root/etc/init.d/athena_led" "$target_dir/root/usr/sbin/athena-led"
                fi
                ;;
        esac
    done
}

# 处理带分支的仓库
process_repos_with_branch() {
    log_processing "处理带分支的仓库"
    
    for repo_name in "${!REPOS_WITH_BRANCH[@]}"; do
        local repo_info="${REPOS_WITH_BRANCH[$repo_name]}"
        local repo_url="${repo_info%|*}"
        local branch="${repo_info#*|}"
        local target_dir="${SPECIAL_HANDLING[$repo_name]:-package/$repo_name}"
        
        clone_repo "$repo_name" "$repo_url" "$target_dir" "$branch"
    done
}

# 处理feeds源
process_feed_sources() {
    log_processing "处理feeds源"
    
    for feed_name in "${!FEED_SOURCES[@]}"; do
        local feed_info="${FEED_SOURCES[$feed_name]}"
        local feed_url="${feed_info%|*}"
        local branch="${feed_info#*|}"
        
        # 如果没有分支信息，branch会等于url，需要处理
        if [ "$branch" = "$feed_url" ]; then
            branch=""
        fi
        
        add_feed "$feed_name" "$feed_url" "$branch"
    done
}

# 处理特殊需求
process_special_requirements() {
    log_processing "处理特殊需求"
    
    # 处理tailscale
    if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
        log_info "处理tailscale特殊需求"
        sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
    fi
}

# 检查并删除冲突软件包
check_and_remove_conflicts() {
    log_processing "检查并删除冲突软件包"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    local removed_count=0
    
    # 检查每个可能冲突的软件包
    for package in "${!FEEDS_PACKAGES[@]}"; do
        local package_list="${FEEDS_PACKAGES[$package]}"
        
        for pkg in $package_list; do
            # 查找官方feeds中的软件包
            local official_packages=$(find ./feeds -name "$pkg" -type d 2>/dev/null)
            
            if [ -n "$official_packages" ]; then
                log_info "发现官方feeds中的冲突软件包: $pkg"
                
                # 删除官方feeds中的软件包
                for pkg_path in $official_packages; do
                    log_info "删除官方软件包: $pkg_path"
                    if rm -rf "$pkg_path"; then
                        log_success "删除成功: $pkg_path"
                        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                        removed_count=$((removed_count + 1))
                    else
                        log_error "删除失败: $pkg_path"
                        ERROR_COUNT=$((ERROR_COUNT + 1))
                    fi
                done
            fi
        done
    done
    
    if [ $removed_count -gt 0 ]; then
        log_success "共删除 $removed_count 个冲突软件包"
    else
        log_info "未发现冲突软件包"
    fi
    
    return 0
}

# 验证feeds.conf.default文件
validate_feeds_config() {
    log_processing "验证feeds.conf.default文件"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 检查文件是否存在
    if [ ! -f "feeds.conf.default" ]; then
        log_error "feeds.conf.default文件不存在"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    # 检查文件语法
    local line_num=0
    local error_count=0
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # 跳过空行和注释行
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # 检查格式是否正确
        if [[ ! "$line" =~ ^src-(git|svn|cvs|hg|link|bzr)[[:space:]]+ ]]; then
            log_error "第 $line_num 行格式错误: $line"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            error_count=$((error_count + 1))
        fi
    done < "feeds.conf.default"
    
    if [ $error_count -eq 0 ]; then
        log_success "feeds.conf.default文件验证通过"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log_error "feeds.conf.default文件验证失败，发现 $error_count 个错误"
        return 1
    fi
}

# 处理所有仓库
process_repos() {
    log_step "处理所有软件源"
    
    # 检查并删除冲突软件包
    check_and_remove_conflicts
    
    # 处理基础仓库
    process_basic_repos
    
    # 处理带分支的仓库
    process_repos_with_branch
    
    # 处理feeds源
    process_feed_sources
    
    # 处理特殊需求
    process_special_requirements
    
    # 验证feeds.conf.default文件
    validate_feeds_config
    
    log_success "所有软件源处理完成"
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN} 执行摘要${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    echo -e "${COLOR_WHITE}总操作数: ${TOTAL_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}成功操作数: ${SUCCESS_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}警告操作数: ${WARNING_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_RED}错误操作数: ${ERROR_COUNT}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}========================================${COLOR_RESET}"
    
    if [ $ERROR_COUNT -eq 0 ]; then
        log_success "所有操作均成功完成"
        return 0
    else
        log_error "存在 $ERROR_COUNT 个错误操作"
        return 1
    fi
}

# =============================================================================
# 主执行流程
# =============================================================================

main() {
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 显示脚本信息
    show_script_info
    
    # 检查环境
    if check_environment; then
        # 处理所有仓库
        if process_repos; then
            generate_final_summary
        else
            generate_final_summary
            log_warning "部分仓库处理失败，但继续执行后续步骤"
        fi
    else
        log_error "环境检查失败，终止执行"
        generate_final_summary
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"
