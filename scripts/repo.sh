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
# 版本: 3.1 - 优化软件包检测版
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
    ["luci-app-openclash"]="luci-app-passwall luci-app-mosdns"
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
    log_info "版本: 3.1 - 优化软件包检测版"
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
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        return 1
    fi
    
    # 检查网络连接（可跳过）
    if [ "${SKIP_NETWORK_CHECK:-0}" != "1" ]; then
        check_network || {
            log_error "网络连接异常，无法继续执行"
            log_info "提示: 可以设置 SKIP_NETWORK_CHECK=1 跳过网络检查"
            exit 1
        }
    else
        log_warn "跳过网络检查（SKIP_NETWORK_CHECK=1）"
    fi
    
    # 检查磁盘空间
    check_disk_space "." 2 || {
        log_error "磁盘空间不足，至少需要2GB空间"
        exit 1
    }
    
    log_success "环境检查通过"
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
    log_error "  2. 仓库是否为公开仓库"
    log_error "  3. 网络连接是否正常"
    log_error "  4. 可以手动访问仓库确认分支信息"
    
    return 1
}

# 检查并删除官方feeds中的软件包
check_and_remove_feeds_packages() {
    local repo_name="$1"
    
    log_info "检查官方feeds中的软件包: $repo_name"
    
    # 获取官方feeds中可能存在的软件包列表
    local feeds_packages="${FEEDS_PACKAGES[$repo_name]}"
    
    if [ -z "$feeds_packages" ]; then
        log_debug "无官方feeds软件包: $repo_name"
        return 0
    fi
    
    # 检查并删除官方feeds中的软件包
    for package in $feeds_packages; do
        log_info "检查官方feeds软件包: $package"
        
        # 在 feeds 目录中查找
        local feeds_paths
        feeds_paths=$(find feeds -name "$package" -type d 2>/dev/null)
        
        if [ -n "$feeds_paths" ]; then
            log_warning "发现官方feeds软件包: $package"
            for path in $feeds_paths; do
                log_info "删除官方feeds软件包: $path"
                safe_remove "$path" true
            done
        fi
    done
    
    return 0
}

# 检查并删除冲突的软件包
check_and_remove_conflicting_packages() {
    local repo_name="$1"
    local target_dir="$2"
    
    log_info "检查冲突软件包: $repo_name"
    
    # 获取可能冲突的软件包列表
    local conflicting_packages="${CONFLICTING_PACKAGES[$repo_name]}"
    
    if [ -z "$conflicting_packages" ]; then
        log_debug "无冲突软件包: $repo_name"
        return 0
    fi
    
    # 检查并删除冲突的软件包
    for package in $conflicting_packages; do
        log_info "检查冲突软件包: $package"
        
        # 在 package 目录中查找
        local package_paths
        package_paths=$(find package -name "$package" -type d 2>/dev/null)
        
        if [ -n "$package_paths" ]; then
            log_warning "发现冲突软件包: $package"
            for path in $package_paths; do
                log_info "删除冲突软件包: $path"
                safe_remove "$path" true
            done
        fi
        
        # 在 feeds 目录中查找
        local feeds_paths
        feeds_paths=$(find feeds -name "$package" -type d 2>/dev/null)
        
        if [ -n "$feeds_paths" ]; then
            log_warning "发现冲突软件包在feeds中: $package"
            for path in $feeds_paths; do
                log_info "删除冲突软件包: $path"
                safe_remove "$path" true
            done
        fi
    done
    
    return 0
}

# 特殊处理：mosdns
handle_mosdns_special() {
    local repo_name="$1"
    local target_dir="$2"
    
    log_info "执行 mosdns 特殊处理..."
    
    # 1. 删除冲突的包
    log_info "删除冲突的 mosdns 和 v2ray-geodata 包..."
    find ./ -name "Makefile" -path "*/v2ray-geodata/*" -exec rm -f {} \; 2>/dev/null || true
    find ./ -name "Makefile" -path "*/mosdns/*" -exec rm -f {} \; 2>/dev/null || true
    
    # 2. 克隆 luci-app-mosdns
    log_info "克隆 luci-app-mosdns..."
    if git clone -b v5 --depth 1 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns; then
        log_success "luci-app-mosdns 克隆成功"
    else
        log_error "luci-app-mosdns 克隆失败"
        return 1
    fi
    
    # 3. 克隆 v2ray-geodata
    log_info "克隆 v2ray-geodata..."
    if git clone --depth 1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata; then
        log_success "v2ray-geodata 克隆成功"
    else
        log_warning "v2ray-geodata 克隆失败，但不影响主要功能"
    fi
    
    log_success "mosdns 特殊处理完成"
    return 0
}

# 特殊处理：OpenClash
handle_openclash_special() {
    log_info "执行 OpenClash 特殊处理..."
    
    # 创建目录
    mkdir -p package/luci-app-openclash
    
    # 使用稀疏检出方式克隆
    log_info "使用稀疏检出方式克隆 OpenClash..."
    cd package/luci-app-openclash
    
    # 初始化仓库
    git init
    
    # 添加远程仓库
    git remote add -f origin https://github.com/vernesong/OpenClash.git
    
    # 设置稀疏检出
    git config core.sparsecheckout true
    echo "luci-app-openclash" >> .git/info/sparse-checkout
    
    # 拉取指定分支
    local branch="master"
    git pull --depth 1 origin "$branch"
    
    # 设置上游分支
    git branch --set-upstream-to=origin/"$branch" "$branch"
    
    # 返回上级目录
    cd - > /dev/null
    
    if [ -d "package/luci-app-openclash/luci-app-openclash" ]; then
        log_success "OpenClash 稀疏检出成功"
        return 0
    else
        log_error "OpenClash 稀疏检出失败"
        return 1
    fi
}

# 特殊处理：athena-led
handle_athena_led_special() {
    log_info "执行 athena-led 特殊处理..."
    
    # 设置执行权限
    log_info "设置 athena-led 执行权限..."
    chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led 2>/dev/null || true
    chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led 2>/dev/null || true
    
    log_success "athena-led 特殊处理完成"
    return 0
}

# 克隆或更新仓库
clone_or_update_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local target_dir="$3"
    local branch="${4:-master}"
    
    log_work "处理仓库: $repo_name"
    
    # 检查是否需要特殊处理
    local special_handling="${SPECIAL_HANDLING[$repo_name]}"
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        log_debug "删除已存在的目录: $target_dir"
        safe_remove "$target_dir" true
    fi
    
    # 克隆仓库
    if git_clone_enhanced "$repo_url" "$target_dir" "$branch" "$repo_name"; then
        log_success "仓库处理成功: $repo_name"
        return 0
    else
        log_error "仓库处理失败: $repo_name"
        return 1
    fi
}

# 预处理 tailscale
preprocess_tailscale() {
    log_info "预处理 tailscale..."
    
    # 修改 feeds/packages/net/tailscale/Makefile
    local makefile="feeds/packages/net/tailscale/Makefile"
    if [ -f "$makefile" ]; then
        log_debug "修改 tailscale Makefile"
        # 备份原文件
        cp "$makefile" "$makefile.bak"
        # 执行修改
        sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' "$makefile"
        log_success "tailscale Makefile 修改完成"
    else
        log_warn "tailscale Makefile 不存在，跳过修改"
    fi
}

# 处理特殊仓库
handle_special_repo() {
    local repo_name="$1"
    local special_handling="${SPECIAL_HANDLING[$repo_name]}"
    
    case "$special_handling" in
        "pre_remove_feeds")
            # 预处理，删除 feeds 中的相关文件
            if [ "$repo_name" = "luci-app-tailscale" ]; then
                preprocess_tailscale
            fi
            ;;
        "mosdns_special")
            # mosdns 特殊处理
            handle_mosdns_special "$repo_name" "package/luci-app-mosdns"
            return $?
            ;;
        "openclash_special")
            # OpenClash 特殊处理
            handle_openclash_special
            return $?
            ;;
        "small")
            # small-package 特殊处理，直接克隆到 small 目录
            return 0
            ;;
        *)
            # 其他特殊处理，目标目录为 special_handling 指定的值
            return 0
            ;;
    esac
    
    return 0
}

# 处理所有仓库
process_repos() {
    log_step "处理第三方软件源"
    
    local total_repos=${#REPOS[@]}
    local processed_count=0
    local success_count=0
    local failed_count=0
    
    log_info "总共需要处理 $total_repos 个仓库"
    
    for repo_name in "${!REPOS[@]}"; do
        ((processed_count++))
        log_info "处理进度: $processed_count/$total_repos - $repo_name"
        
        local repo_url="${REPOS[$repo_name]}"
        local target_dir="package/$repo_name"
        local branch="master"
        
        # 解析仓库URL和分支
        if [[ "$repo_url" =~ -b[[:space:]]+([^[:space:]]+) ]]; then
            branch="${BASH_REMATCH[1]}"
            repo_url="${repo_url%%-b*}"
        fi
        
        # 检查并删除官方feeds中的软件包
        check_and_remove_feeds_packages "$repo_name"
        
        # 检查是否需要特殊处理
        local special_handling="${SPECIAL_HANDLING[$repo_name]}"
        if [ -n "$special_handling" ]; then
            # 执行特殊处理
            if handle_special_repo "$repo_name"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
            
            # 如果是特殊处理且成功，跳过常规克隆
            if [[ "$special_handling" =~ "mosdns_special|openclash_special" ]] && [ $? -eq 0 ]; then
                continue
            fi
            
            # 如果 special_handling 是目录路径，则使用它作为目标目录
            if [[ "$special_handling" == */* ]]; then
                target_dir="$special_handling"
            elif [ "$special_handling" = "small" ]; then
                target_dir="small"
            fi
        fi
        
        # 检查并删除冲突的软件包
        check_and_remove_conflicting_packages "$repo_name" "$target_dir"
        
        # 克隆或更新仓库
        if clone_or_update_repo "$repo_name" "$repo_url" "$target_dir" "$branch"; then
            ((success_count++))
            
            # athena-led 特殊处理（在克隆成功后执行）
            if [ "$repo_name" = "luci-app-athena-led" ]; then
                handle_athena_led_special
            fi
        else
            ((failed_count++))
        fi
        
        # 添加延迟，避免触发 GitHub API 限制
        if [ $processed_count -lt $total_repos ]; then
            log_debug "等待 2 秒后处理下一个仓库..."
            sleep 2
        fi
    done
    
    # 显示处理结果
    log_info "仓库处理完成: 成功 $success_count/$total_repos, 失败 $failed_count/$total_repos"
    
    if [ $failed_count -gt 0 ]; then
        log_warning "部分仓库处理失败，可能影响编译结果"
        return 1
    else
        log_success "所有仓库处理成功"
        return 0
    fi
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    show_execution_summary
    
    echo ""
    echo "处理的仓库列表:"
    for repo_name in "${!REPOS[@]}"; do
        echo "  - $repo_name: ${REPOS[$repo_name]}"
    done
    echo ""
    
    # 显示网络状态
    log_info "网络状态检查完成"
    log_info "如果多个仓库克隆失败，请检查网络连接或稍后重试"
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
            # 生成摘要报告
            generate_final_summary
        else
            # 即使有失败也生成摘要报告
            generate_final_summary
            log_warning "部分仓库处理失败，但继续执行后续步骤"
        fi
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"