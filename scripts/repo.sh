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
# 版本: 3.1 - 修复版
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

# --- 函数定义 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 3.1 - 修复版"
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
    
    log_success "环境检查通过"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 克隆仓库
clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-}"
    
    log_processing "正在克隆 $repo_url 到 $target_dir"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        log_info "目标目录已存在，删除旧目录"
        rm -rf "$target_dir"
    fi
    
    # 克隆仓库
    if [ -n "$branch" ]; then
        if git clone -b "$branch" "$repo_url" "$target_dir"; then
            log_success "克隆成功: $target_dir"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $target_dir"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    else
        if git clone "$repo_url" "$target_dir"; then
            log_success "克隆成功: $target_dir"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            log_error "克隆失败: $target_dir"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    fi
}

# 添加软件源到feeds.conf.default
add_feed() {
    local feed_type="$1"
    local feed_url="$2"
    local feed_branch="${3:-}"
    
    log_processing "添加软件源: $feed_type $feed_url"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    local feed_entry="src-git $feed_type $feed_url"
    if [ -n "$feed_branch" ]; then
        feed_entry="$feed_entry;$feed_branch"
    fi
    
    # 检查是否已存在相同的软件源
    if grep -q "$feed_entry" feeds.conf.default; then
        log_warning "软件源已存在，跳过添加: $feed_entry"
        WARNING_COUNT=$((WARNING_COUNT + 1))
        return 1
    fi
    
    # 添加软件源
    if echo "$feed_entry" >> feeds.conf.default; then
        log_success "添加软件源成功: $feed_entry"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        log_error "添加软件源失败: $feed_entry"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
}

# 检查并删除官方feeds中可能存在的不同名称的软件包
check_and_remove_conflicts() {
    log_processing "检查并删除官方feeds中可能存在的不同名称的软件包"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 定义可能冲突的软件包列表
    local conflict_packages=(
        "luci-app-adguardhome"
        "luci-app-ddns-go"
        "luci-app-netdata"
        "luci-app-netspeedtest"
        "luci-app-partexp"
        "luci-app-taskplan"
        "luci-app-lucky"
        "luci-app-easytier"
        "luci-app-momo"
        "luci-app-nikki"
        "luci-app-oaf"
        "luci-app-openclash"
        "luci-app-tailscale"
        "luci-app-vnt"
        "luci-app-openlist2"
        "luci-app-quickfile"
        "luci-app-passwall"
        "luci-app-passwall2"
    )
    
    local removed_count=0
    
    # 检查每个可能冲突的软件包
    for package in "${conflict_packages[@]}"; do
        # 查找官方feeds中的软件包
        local official_packages=$(find ./feeds -name "$package" -type d 2>/dev/null)
        
        if [ -n "$official_packages" ]; then
            log_info "发现官方feeds中的冲突软件包: $package"
            
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
        if [[ ! "$line" =~ ^src- ]]; then
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

# 添加第三方软件源
add_third_party_feeds() {
    log_step "添加第三方软件源"
    
    # 京东云雅典娜led控制
    clone_repo "https://github.com/NONGFAH/luci-app-athena-led" "package/luci-app-athena-led"
    if [ -d "package/luci-app-athena-led" ]; then
        chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
    fi
    
    # passwall by xiaorouji
    add_feed "passwall_packages" "https://github.com/xiaorouji/openwrt-passwall-packages.git" "main"
    add_feed "passwall_luci" "https://github.com/xiaorouji/openwrt-passwall.git" "main"
    
    # passwall2 by xiaorouji
    add_feed "luci-app-passwall2" "https://github.com/xiaorouji/openwrt-passwall2.git" "main"
    
    # AdGuardHome
    clone_repo "https://github.com/sirpdboy/luci-app-adguardhome" "package/luci-app-adguardhome"
    
    # ddns-go by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-ddns-go" "package/luci-app-ddns-go"
    
    # luci-app-netdata by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-netdata" "package/luci-app-netdata"
    
    # luci-app-netspeedtest by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"
    
    # luci-app-partexp by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-partexp" "package/luci-app-partexp"
    
    # luci-app-taskplan by sirpdboy
    clone_repo "https://github.com/sirpdboy/luci-app-taskplan" "package/luci-app-taskplan"
    
    # lucky by gdy666
    clone_repo "https://github.com/gdy666/luci-app-lucky" "package/lucky"
    
    # luci-app-easytier
    clone_repo "https://github.com/EasyTier/luci-app-easytier" "package/luci-app-easytier"
    
    # homeproxy
    clone_repo "https://github.com/VIKINGYFY/homeproxy" "package/homeproxy"
    
    # golang & luci-app-openlist2 by sbwml
    clone_repo "https://github.com/sbwml/packages_lang_golang" "feeds/packages/lang/golang" "25.x"
    clone_repo "https://github.com/sbwml/luci-app-openlist2" "package/luci-app-openlist2"
    
    # luci-app-mosdns by sbwml
    clone_repo "https://github.com/sbwml/luci-app-mosdns" "package/luci-app-mosdns" "v5"
    
    # luci-app-quickfile by sbwml
    clone_repo "https://github.com/sbwml/luci-app-quickfile" "package/luci-app-quickfile"
    
    # momo和nikki - 直接添加到feeds.conf.default而不是使用echo
    add_feed "momo" "https://github.com/nikkinikki-org/OpenWrt-momo.git" "main"
    add_feed "nikki" "https://github.com/nikkinikki-org/OpenWrt-nikki.git" "main"
    
    # OpenAppFilter（OAF）
    clone_repo "https://github.com/destan19/OpenAppFilter" "package/luci-app-oaf"
    
    # luci-app-openclash by vernesong
    add_feed "luci-app-openclash" "https://github.com/vernesong/OpenClash.git"
    
    # tailscale
    sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
    clone_repo "https://github.com/asvow/luci-app-tailscale" "package/luci-app-tailscale"
    
    # vnt
    clone_repo "https://github.com/lmq8267/luci-app-vnt" "package/luci-app-vnt"
    
    # kenzok8/small-package，后备之选
    clone_repo "https://github.com/kenzok8/small-package" "small"
    
    # 验证feeds.conf.default文件
    validate_feeds_config
    
    log_success "第三方软件源添加完成"
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
        # 检查并删除官方feeds中可能存在的不同名称的软件包
        check_and_remove_conflicts
        
        # 添加第三方软件源
        add_third_party_feeds
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        ERROR_COUNT=$((ERROR_COUNT + 1))
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

# ==============================================================================
# 原始代码备份（供参考）
# ==============================================================================

# 京东云雅典娜led控制
# git clone https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
# chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# passwall by xiaorouji，
# 执行 ./scripts/feeds update -a 操作前，在 feeds.conf.default 顶部插入如下代码：
# src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main
# src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main

# passwall2 by xiaorouji，
# src-git luci-app-passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main

# AdGuardHome，官方推荐OpenWrt LUCI app by @kongfl888 (originally by @rufengsuixing).作为备选
# 首选使用luci-app-adguardhome by sirpdboy
# git clone https://github.com/sirpdboy/luci-app-adguardhome package/luci-app-adguardhome
# git clone https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome

# ddns-go by sirpdboy，自带luci-app
# git clone https://github.com/sirpdboy/luci-app-ddns-go package/luci-app-ddns-go

# luci-app-netdata by sirpdboy
# git clone https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata

# luci-app-netspeedtest by sirpdboy
# git clone https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest

# luci-app-partexp by sirpdboy
# git clone https://github.com/sirpdboy/luci-app-partexp package/luci-app-partexp

# luci-app-taskplan by sirpdboy
# git clone https://github.com/sirpdboy/luci-app-taskplan package/luci-app-taskplan

# lucky by gdy666，自带luci-app，sirpdboy也有luci-app但是可能与原作者有冲突，使用原作者，sirpdboy备选
# git clone https://github.com/gdy666/luci-app-lucky package/lucky
# git clone https://github.com/sirpdboy/luci-app-lucky package/lucky

# luci-app-easytier
# git clone https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier

# frp https://github.com/fatedier/frp，无luci-app，建议使用small-package更新

# homeproxy immortalwrt官方出品，无luci-app，建议使用https://github.com/VIKINGYFY/homeproxy更新
# git clone https://github.com/VIKINGYFY/homeproxy package/homeproxy
# 一个更方便地生成 ImmortalWrt/OpenWrt(23.05.x+) HomeProxy 插件大多数常用配置的脚本。
# (必备) 通过私密 Gist 或其它可被正常访问的私有链接定制你的专属 rules.sh 配置内容；
# 执行以下命令（脚本执行期间会向你索要你的定制配置URL）：bash -c "$(curl -fsSl https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh)"

# golang & luci-app-openlist2 by sbwml
# git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
# git clone https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2

# luci-app-mosdns by sbwml
# git clone -b v5 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# luci-app-quickfile by sbwml
# git clone https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# luci-app-istorex（向导模式及主体）/luci-app-quickstart（网络向导和首页界面）/luci-app-diskman （磁盘管理），建议使用small-package更新

# momo在 OpenWrt 上使用 sing-box 进行透明代理/nikki在 OpenWrt 上使用 Mihomo 进行透明代理。
# echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo;main" >> "feeds.conf.default"
# echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki;main" >> "feeds.conf.default"
# git clone https://github.com/nikkinikki-org/OpenWrt-momo package/luci-app-momo
# git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# OpenAppFilter（OAF），自带luci-app
# git clone https://github.com/destan19/OpenAppFilter package/luci-app-oaf

# luci-app-openclash by vernesong
# src-git luci-app-openclash https://github.com/vernesong/OpenClash.git

# tailscale，官方推荐luci-app-tailscale by asvow
# sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
# git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# vnt，官方https://github.com/vnt-dev/vnt，无luci-app，使用lmq8267
# git clone https://github.com/lmq8267/luci-app-vnt package/luci-app-vnt

# kenzok8/small-package，后备之选，只有上述的ipk地址缺失才会用到。
# git clone https://github.com/kenzok8/small-package small
