#!/bin/bash

# ==============================================================================
# OpenWrt/ImmortalWrt 编译脚本通用函数库
#
# 功能:
#   提供通用的日志、错误处理、文件操作等功能
#
# 作者: Mary
# 日期：20251114
# 版本: 2.2 - 优化环境检查版
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
export ICON_STEP="📋"
export ICON_DISK="💾"
export ICON_CACHE="📦"

# --- 全局变量 ---
export SUCCESS_COUNT=0
export ERROR_COUNT=0
export WARN_COUNT=0
export FAILED_OPERATIONS=()
export START_TIME=$(date +%s)

# --- 环境检查函数 ---
check_openwrt_environment() {
    local check_type="${1:-basic}"
    
    case "$check_type" in
        "basic")
            # 基础环境检查
            if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
                log_error "不在OpenWrt/ImmortalWrt源码根目录"
                return 1
            fi
            ;;
        "full")
            # 完整环境检查
            local required_commands=("git" "grep" "sed" "find" "curl" "make")
            for cmd in "${required_commands[@]}"; do
                check_command_exists "$cmd" || return 1
            done
            
            if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
                log_error "不在OpenWrt/ImmortalWrt源码根目录"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# --- 日志函数 ---
log() {
    local level="$1"
    local message="$2"
    local color="$3"
    local icon="$4"
    
    echo -e "${color}[$(date '+%H:%M:%S')] [${level}] ${icon} ${message}${NC}"
}

log_info() {
    log "INFO" "$1" "$BLUE" "$ICON_INFO"
}

log_success() {
    log "OK" "$1" "$GREEN" "$ICON_SUCCESS"
    ((SUCCESS_COUNT++))
}

log_warning() {
    log "WARN" "$1" "$YELLOW" "$ICON_WARNING"
    ((WARN_COUNT++))
}

log_error() {
    log "ERROR" "$1" "$RED" "$ICON_ERROR"
    ((ERROR_COUNT++))
    FAILED_OPERATIONS+=("$1")
}

log_work() {
    log "WORK" "$1" "$PURPLE" "$ICON_WORK"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        log "DEBUG" "$1" "$CYAN" "$ICON_DEBUG"
    fi
}

log_time() {
    log "TIME" "$1" "$WHITE" "$ICON_TIME"
}

log_step() {
    echo ""
    echo "=================================================================="
    log_info "$1"
    echo "=================================================================="
}

log_disk() {
    log "DISK" "$1" "$CYAN" "$ICON_DISK"
}

log_cache() {
    log "CACHE" "$1" "$PURPLE" "$ICON_CACHE"
}

# --- 文件操作函数 ---
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
        if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null 2>&1; then
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

# --- 系统操作函数 ---
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

show_disk_usage() {
    local path="${1:-.}"
    local description="${2:-当前目录}"
    
    log_disk "磁盘使用情况 ($description):"
    df -hT "$path"
    
    if [ -d "$path" ]; then
        local dir_size
        dir_size=$(du -sh "$path" 2>/dev/null | cut -f1)
        log_disk "目录大小: $dir_size"
    fi
}

# --- 配置文件操作函数 ---
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

extract_enabled_luci_packages() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "从配置文件提取启用的LUCI软件包: $config_file"
    
    local packages
    packages=$(grep "^CONFIG_PACKAGE_luci-app.*=y$" "$config_file" | sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | sort)
    
    if [ -z "$packages" ]; then
        log_warning "未找到启用的LUCI软件包配置"
        return 1
    fi
    
    echo "$packages"
    return 0
}

# --- 其他实用函数 ---
generate_random_string() {
    local length="${1:-16}"
    
    if command -v openssl > /dev/null 2>&1; then
        openssl rand -hex "$((length/2))"
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
    fi
}

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

show_execution_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo ""
    echo "=================================================================="
    log_info "📊 执行摘要"
    echo "=================================================================="
    echo "✅ 成功操作: $SUCCESS_COUNT"
    echo "❌ 失败操作: $ERROR_COUNT"
    echo "⚠️  警告操作: $WARN_COUNT"
    echo "⏱️  执行时间: ${duration}秒"
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