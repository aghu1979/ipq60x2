#!/bin/bash

# ==============================================================================
# OpenWrt/ImmortalWrt 编译脚本通用函数库
#
# 功能:
#   提供通用的日志、错误处理、文件操作等功能
#
# 作者: Mary
# 日期：20251107
# 版本: 1.0 - 初始版本
# ==============================================================================

# --- 颜色定义 ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# --- 图标定义 ---
export ICON_INFO="ℹ️"
export ICON_SUCCESS="✅"
export ICON_WARNING="⚠️"
export ICON_ERROR="❌"
export ICON_WORK="🔧"
export ICON_DEBUG="🐛"
export ICON_TIME="⏱️"

# --- 全局变量 ---
export SUCCESS_COUNT=0
export ERROR_COUNT=0
export WARN_COUNT=0
export FAILED_OPERATIONS=()

# --- 日志函数 ---

# 通用日志函数
log() {
    local level="$1"
    local message="$2"
    local color="$3"
    local icon="$4"
    
    echo -e "${color}[${level}] ${icon} ${message}${NC}"
}

# 信息日志
log_info() {
    log "INFO" "$1" "$BLUE" "$ICON_INFO"
}

# 成功日志
log_success() {
    log "OK" "$1" "$GREEN" "$ICON_SUCCESS"
    ((SUCCESS_COUNT++))
}

# 警告日志
log_warning() {
    log "WARN" "$1" "$YELLOW" "$ICON_WARNING"
    ((WARN_COUNT++))
}

# 错误日志
log_error() {
    log "ERROR" "$1" "$RED" "$ICON_ERROR"
    ((ERROR_COUNT++))
    FAILED_OPERATIONS+=("$1")
}

# 工作日志
log_work() {
    log "WORK" "$1" "$PURPLE" "$ICON_WORK"
}

# 调试日志
log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        log "DEBUG" "$1" "$CYAN" "$ICON_DEBUG"
    fi
}

# 时间日志
log_time() {
    log "TIME" "$1" "$WHITE" "$ICON_TIME"
}

# 步骤日志
log_step() {
    echo ""
    echo "=================================================================="
    log_info "$1"
    echo "=================================================================="
}

# --- 文件操作函数 ---

# 安全删除文件或目录
safe_remove() {
    local path="$1"
    local force="${2:-false}"
    
    if [ -z "$path" ]; then
        log_error "路径不能为空"
        return 1
    fi
    
    if [ ! -e "$path" ]; then
        log_debug "路径不存在: $path"
        return 0
    fi
    
    log_debug "删除路径: $path"
    
    if [ "$force" = "true" ]; then
        rm -rf "$path" || {
            log_error "无法删除路径: $path"
            return 1
        }
    else
        rm -r "$path" || {
            log_error "无法删除路径: $path"
            return 1
        }
    fi
    
    return 0
}

# 安全创建目录
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [ -z "$dir" ]; then
        log_error "目录路径不能为空"
        return 1
    fi
    
    if [ -d "$dir" ]; then
        log_debug "目录已存在: $dir"
        return 0
    fi
    
    log_debug "创建目录: $dir"
    mkdir -p "$dir" || {
        log_error "无法创建目录: $dir"
        return 1
    }
    
    chmod "$mode" "$dir" || {
        log_warning "无法设置目录权限: $dir"
    }
    
    return 0
}

# 安全复制文件或目录
safe_copy() {
    local src="$1"
    local dest="$2"
    local recursive="${3:-false}"
    
    if [ -z "$src" ] || [ -z "$dest" ]; then
        log_error "源路径和目标路径不能为空"
        return 1
    fi
    
    if [ ! -e "$src" ]; then
        log_error "源路径不存在: $src"
        return 1
    fi
    
    log_debug "复制: $src -> $dest"
    
    if [ "$recursive" = "true" ]; then
        cp -r "$src" "$dest" || {
            log_error "复制失败: $src -> $dest"
            return 1
        }
    else
        cp "$src" "$dest" || {
            log_error "复制失败: $src -> $dest"
            return 1
        }
    fi
    
    return 0
}

# --- 网络操作函数 ---

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    local test_urls=(
        "https://www.github.com"
        "https://api.github.com"
    )
    
    for url in "${test_urls[@]}"; do
        log_debug "测试连接: $url"
        if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null 2>&1; then
            log_success "网络连接正常"
            return 0
        fi
    done
    
    log_error "网络连接异常"
    return 1
}

# Git 克隆函数
git_clone() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-master}"
    
    if [ -z "$repo_url" ] || [ -z "$target_dir" ]; then
        log_error "仓库URL和目标目录不能为空"
        return 1
    fi
    
    log_info "克隆仓库: $repo_url (分支: $branch)"
    
    if [ -d "$target_dir" ]; then
        log_debug "目标目录已存在，先删除: $target_dir"
        safe_remove "$target_dir" true
    fi
    
    git clone -b "$branch" "$repo_url" "$target_dir" || {
        log_error "克隆仓库失败: $repo_url"
        return 1
    }
    
    return 0
}

# --- 系统操作函数 ---

# 检查命令是否存在
check_command_exists() {
    local cmd="$1"
    
    if command -v "$cmd" > /dev/null 2>&1; then
        log_debug "命令存在: $cmd"
        return 0
    else
        log_error "命令不存在: $cmd"
        return 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    local path="${1:-.}"
    local min_space_gb="${2:-5}"
    
    log_info "检查磁盘空间: $path"
    
    local available_kb
    available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    log_info "可用空间: ${available_gb}GB"
    
    if [ "$available_gb" -lt "$min_space_gb" ]; then
        log_warning "磁盘空间不足，建议至少 ${min_space_gb}GB，当前 ${available_gb}GB"
        return 1
    fi
    
    log_success "磁盘空间充足"
    return 0
}

# 扩展磁盘空间
expand_disk_space() {
    local device="${1:-sda1}"
    
    log_info "扩展磁盘空间: /dev/$device"
    
    # 检查设备是否存在
    if [ ! -b "/dev/$device" ]; then
        log_warning "设备不存在: /dev/$device"
        return 1
    fi
    
    # 检查是否已挂载
    if ! mount | grep -q "/dev/$device"; then
        log_info "设备未挂载，尝试挂载: /dev/$device"
        
        # 创建挂载点
        local mount_point="/mnt/$device"
        safe_mkdir "$mount_point"
        
        # 挂载设备
        mount "/dev/$device" "$mount_point" || {
            log_error "挂载设备失败: /dev/$device"
            return 1
        }
        
        log_success "设备挂载成功: /dev/$device -> $mount_point"
        
        # 创建工作目录
        local workspace_dir="$mount_point/workspace"
        safe_mkdir "$workspace_dir"
        
        # 返回工作目录路径
        echo "$workspace_dir"
        return 0
    else
        log_info "设备已挂载: /dev/$device"
        local mount_point
        mount_point=$(mount | grep "/dev/$device" | awk '{print $3}')
        
        # 创建工作目录
        local workspace_dir="$mount_point/workspace"
        safe_mkdir "$workspace_dir"
        
        # 返回工作目录路径
        echo "$workspace_dir"
        return 0
    fi
}

# --- 配置文件操作函数 ---

# 从配置文件中提取设备列表
extract_devices_from_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "从配置文件提取设备列表: $config_file"
    
    local devices
    devices=$(grep "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y$" "$config_file" | sed 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_\(.*\)=y$/\1/' | sort -u)
    
    if [ -z "$devices" ]; then
        log_warning "未找到设备配置"
        return 1
    fi
    
    echo "$devices"
    return 0
}

# --- 缓存操作函数 ---

# 设置缓存键
set_cache_key() {
    local repo_url="$1"
    local branch="$2"
    local commit_hash
    
    if [ -d ".git" ]; then
        commit_hash=$(git rev-parse HEAD)
    else
        commit_hash="unknown"
    fi
    
    # 生成缓存键
    local cache_key
    cache_key="${repo_url//[^a-zA-Z0-9]/_}-${branch}-${commit_hash}"
    
    echo "$cache_key"
}

# 检查缓存是否存在
check_cache_exists() {
    local cache_key="$1"
    local cache_dir="${2:-/tmp/openwrt-cache}"
    
    if [ -d "$cache_dir/$cache_key" ]; then
        log_debug "缓存存在: $cache_key"
        return 0
    else
        log_debug "缓存不存在: $cache_key"
        return 1
    fi
}

# 保存缓存
save_cache() {
    local source_dir="$1"
    local cache_key="$2"
    local cache_dir="${3:-/tmp/openwrt-cache}"
    
    if [ ! -d "$source_dir" ]; then
        log_error "源目录不存在: $source_dir"
        return 1
    fi
    
    safe_mkdir "$cache_dir"
    
    local target_cache_dir="$cache_dir/$cache_key"
    
    log_info "保存缓存: $source_dir -> $target_cache_dir"
    
    # 如果缓存已存在，先删除
    if [ -d "$target_cache_dir" ]; then
        safe_remove "$target_cache_dir" true
    fi
    
    # 复制到缓存目录
    safe_copy "$source_dir" "$target_cache_dir" true || {
        log_error "保存缓存失败"
        return 1
    }
    
    log_success "缓存保存成功"
    return 0
}

# 恢复缓存
restore_cache() {
    local cache_key="$1"
    local target_dir="$2"
    local cache_dir="${3:-/tmp/openwrt-cache}"
    
    local source_cache_dir="$cache_dir/$cache_key"
    
    if [ ! -d "$source_cache_dir" ]; then
        log_error "缓存不存在: $cache_key"
        return 1
    fi
    
    log_info "恢复缓存: $source_cache_dir -> $target_dir"
    
    # 如果目标目录已存在，先删除
    if [ -d "$target_dir" ]; then
        safe_remove "$target_dir" true
    fi
    
    # 复制到目标目录
    safe_copy "$source_cache_dir" "$target_dir" true || {
        log_error "恢复缓存失败"
        return 1
    }
    
    log_success "缓存恢复成功"
    return 0
}

# --- 其他实用函数 ---

# 生成随机字符串
generate_random_string() {
    local length="${1:-16}"
    
    if command -v openssl > /dev/null 2>&1; then
        openssl rand -hex "$((length/2))"
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
    fi
}

# 等待用户确认
wait_for_confirmation() {
    local message="${1:-是否继续? (y/N)}"
    local default="${2:-N}"
    
    echo -n -e "${YELLOW}[QUESTION] ${ICON_INFO} $message ${NC}"
    
    local response
    read -r response
    
    if [ -z "$response" ]; then
        response="$default"
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 显示执行摘要
show_execution_summary() {
    echo ""
    echo "=================================================================="
    log_info "📊 执行摘要"
    echo "=================================================================="
    echo "✅ 成功操作: $SUCCESS_COUNT"
    echo "❌ 失败操作: $ERROR_COUNT"
    echo "⚠️  警告操作: $WARN_COUNT"
    echo ""
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "失败的操作列表:"
        for operation in "${FAILED_OPERATIONS[@]}"; do
            echo "  - $operation"
        done
        echo ""
    fi
    
    if [ $ERROR_COUNT -eq 0 ]; then
        log_success "🎉 所有操作完成！"
    else
        log_warning "⚠️  部分操作失败，请检查上述错误信息"
    fi
    echo "=================================================================="
}
