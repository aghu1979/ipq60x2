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
# 日期：20251107
# 版本: 2.12 - 企业级优化版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 软件源列表
declare -A REPOS=(
    ["luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led"
    ["luci-app-passwall"]="https://github.com/xiaorouji/openwrt-passwall"
    ["luci-app-passwall2"]="https://github.com/xiaorouji/openwrt-passwall2"
    ["passwall-packages"]="https://github.com/xiaorouji/openwrt-passwall-packages"
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
)

# 特殊处理列表
declare -A SPECIAL_HANDLING=(
    ["packages_lang_golang"]="feeds/packages/lang/golang"
    ["luci-app-tailscale"]="pre_remove_feeds"
    ["luci-app-mosdns"]="mosdns_special"
    ["luci-app-openclash"]="openclash_special"
    ["passwall-packages"]="passwall_special"
    ["small-package"]="small"
)

# 可能冲突的软件包列表（不同名称但功能相同）
declare -A CONFLICTING_PACKAGES=(
    ["luci-app-lucky"]="luci-app-lucky-sirpdboy"
    ["luci-app-homeproxy"]="homeproxy"
    ["luci-app-openclash"]="luci-app-passwall luci-app-mosdns"
    ["luci-app-tailscale"]="tailscale"
    ["luci-app-vnt"]="vnt"
    ["luci-app-momo"]="sing-box"
    ["luci-app-nikki"]="mihomo"
    ["luci-app-oaf"]="openappfilter"
    ["luci-app-adguardhome"]="adguardhome"
    ["luci-app-passwall"]="passwall"
    ["luci-app-passwall2"]="passwall2"
)

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt 第三方软件源集成脚本"
    log_info "作者: Mary"
    log_info "版本: 2.12 - 企业级优化版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查环境
check_environment() {
    log_info "检查执行环境..."
    
    # 检查必要命令
    local required_commands=("git" "grep" "sed" "find" "curl")
    for cmd in "${required_commands[@]}"; do
        check_command_exists "$cmd" || exit 1
    done
    
    # 检查 jq（可选）
    if command -v jq > /dev/null 2>&1; then
        log_debug "检测到 jq 命令，将用于 JSON 解析"
    else
        log_debug "未检测到 jq 命令，将使用文本解析"
    fi
    
    # 检查网络连接（可跳过）
    if [ "${SKIP_NETWORK_CHECK:-0}" != "1" ]; then
        check_network || {
            log_error "网络连接异常，无法继续执行"
            log_info "提示: 可以设置 SKIP_NETWORK_CHECK=1 跳过网络检查"
            exit 1
        }
    else
        log_warning "跳过网络检查（SKIP_NETWORK_CHECK=1）"
    fi
    
    log_success "环境检查通过"
}

# 增强的网络检查
check_network() {
    log_info "检查网络连接..."
    
    local test_urls=(
        "https://www.github.com"
        "https://api.github.com"
        "https://raw.githubusercontent.com"
    )
    
    local success_count=0
    local total_count=${#test_urls[@]}
    
    for url in "${test_urls[@]}"; do
        log_debug "测试连接: $url"
        if curl -s --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 5 "$url" > /dev/null 2>&1; then
            ((success_count++))
            log_debug "连接成功: $url"
        else
            log_debug "连接失败: $url"
        fi
    done
    
    local success_rate=$((success_count * 100 / total_count))
    log_info "网络连接成功率: ${success_rate}% ($success_count/$total_count)"
    
    if [ $success_rate -ge 66 ]; then
        log_success "网络连接正常"
        return 0
    else
        log_error "网络连接异常"
        return 1
    fi
}

# 获取仓库的默认分支（增强版，带重试）
get_default_branch() {
    local repo_url="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-2}"
    
    log_debug "检测仓库默认分支: $repo_url"
    
    # 从 URL 提取 owner 和 repo
    if [[ "$repo_url" =~ ^https://github\.com/([^/]+)/([^/]+)$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local api_url="https://api.github.com/repos/$owner/$repo"
        
        log_debug "API URL: $api_url"
        
        local attempt=1
        while [ $attempt -le $max_retries ]; do
            log_debug "尝试获取默认分支 (第 $attempt 次)"
            
            # 获取仓库信息
            local repo_info
            repo_info=$(curl -s --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 1 "$api_url" 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$repo_info" ]; then
                # 尝试使用 jq 解析
                if command -v jq > /dev/null 2>&1; then
                    default_branch=$(echo "$repo_info" | jq -r '.default_branch // empty' 2>/dev/null)
                else
                    # 如果没有 jq，使用 grep 和 sed
                    default_branch=$(echo "$repo_info" | grep -o '"default_branch": *"[^"]*"' | sed 's/"default_branch": *"\([^"]*\)"/\1/' 2>/dev/null)
                fi
                
                if [ -n "$default_branch" ] && [ "$default_branch" != "null" ] && [ "$default_branch" != "empty" ]; then
                    log_debug "检测到默认分支: $default_branch"
                    echo "$default_branch"
                    return 0
                fi
            else
                log_debug "API 调用失败 (第 $attempt 次)"
            fi
            
            if [ $attempt -lt $max_retries ]; then
                log_debug "等待 $retry_delay 秒后重试..."
                sleep $retry_delay
            fi
            
            ((attempt++))
        done
    fi
    
    log_debug "无法检测默认分支"
    return 1
}

# 智能分支选择器（按优先级）
smart_branch_selector() {
    local repo_url="$1"
    local user_branch="$2"
    local branches_to_try=()
    
    # 1. API检测默认分支（最高优先级）
    local default_branch
    default_branch=$(get_default_branch "$repo_url" 3 2)
    if [ $? -eq 0 ] && [ -n "$default_branch" ]; then
        branches_to_try+=("$default_branch")
        log_debug "添加API检测的默认分支: $default_branch"
    fi
    
    # 2. 用户指定分支（第二优先级）
    if [ -n "$user_branch" ]; then
        # 避免重复添加
        if [[ ! " ${branches_to_try[@]} " =~ " ${user_branch} " ]]; then
            branches_to_try+=("$user_branch")
            log_debug "添加用户指定分支: $user_branch"
        fi
    fi
    
    # 3. main（第三优先级）
    if [[ ! " ${branches_to_try[@]} " =~ " main " ]]; then
        branches_to_try+=("main")
        log_debug "添加分支: main"
    fi
    
    # 4. master（第四优先级）
    if [[ ! " ${branches_to_try[@]} " =~ " master " ]]; then
        branches_to_try+=("master")
        log_debug "添加分支: master"
    fi
    
    # 返回分支列表（用空格分隔）
    echo "${branches_to_try[@]}"
}

# 增强的 Git 克隆函数
git_clone_enhanced() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-master}"
    local repo_name="$4"
    
    if [ -z "$repo_url" ] || [ -z "$target_dir" ]; then
        log_error "仓库URL和目标目录不能为空"
        return 1
    fi
    
    # 清理URL中的空格
    repo_url=$(echo "$repo_url" | sed 's/[[:space:]]*$//')
    
    log_info "克隆仓库: $repo_url"
    
    # 清理可能存在的目录
    if [ -d "$target_dir" ]; then
        log_debug "删除已存在的目录: $target_dir"
        safe_remove "$target_dir" true
    fi
    
    # 获取按优先级排序的分支列表
    local branches_to_try
    read -ra branches_to_try <<< "$(smart_branch_selector "$repo_url" "$branch")"
    
    log_info "分支尝试顺序: ${branches_to_try[*]}"
    
    # 尝试克隆每个分支
    local attempt=1
    for current_branch in "${branches_to_try[@]}"; do
        log_debug "尝试克隆 (第 $attempt 次): $repo_url (分支: $current_branch)"
        
        # 尝试克隆
        git clone -b "$current_branch" --depth 1 "$repo_url" "$target_dir" 2>&1 | tee /tmp/git_clone_$$.log
        local clone_result=$?
        
        if [ $clone_result -eq 0 ] && [ -d "$target_dir" ]; then
            log_success "仓库克隆成功: $repo_url (分支: $current_branch)"
            return 0
        else
            log_warning "克隆失败 (第 $attempt 次): $repo_url (分支: $current_branch)"
            
            # 显示错误信息
            if [ -f "/tmp/git_clone_$$.log" ]; then
                local error_msg
                error_msg=$(tail -3 /tmp/git_clone_$$.log | grep -i "fatal\|error" | head -1)
                if [ -n "$error_msg" ]; then
                    log_debug "错误信息: $error_msg"
                fi
            fi
            
            # 清理失败的尝试
            if [ -d "$target_dir" ]; then
                safe_remove "$target_dir" true
            fi
            
            ((attempt++))
        fi
    done
    
    # 清理日志文件
    rm -f /tmp/git_clone_$$.log
    
    # 友好的错误提示
    log_error "仓库克隆失败: $repo_url"
    log_error "尝试的分支: ${branches_to_try[*]}"
    
    # 获取默认分支信息用于提示
    local default_branch
    default_branch=$(get_default_branch "$repo_url" 1 1)
    
    if [ $? -eq 0 ] && [ -n "$default_branch" ]; then
        log_error "仓库默认分支: $default_branch"
    else
        log_error "无法获取仓库默认分支信息（可能是API限制）"
    fi
    
    log_error "请检查:"
    log_error "  1. 仓库地址是否正确: $repo_url"
    log_error