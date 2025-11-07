#!/bin/bash

# ==============================================================================
# 通用函数库 - 企业级增强版
# 
# 功能:
#   提供通用的日志记录、错误处理、文件操作、Git操作、网络操作等功能
#   为其他脚本提供基础支持
#
# 作者: Mary
# 日期：20251107
# 版本: 3.2 - 企业级优化版
# ==============================================================================

# --- 颜色和图标定义 ---
export RED='\033[0;31m'       # 红色 - 用于错误信息
export GREEN='\033[0;32m'     # 绿色 - 用于成功信息
export YELLOW='\033[1;33m'    # 黄色 - 用于警告信息
export BLUE='\033[0;34m'      # 蓝色 - 用于信息提示
export PURPLE='\033[0;35m'    # 紫色 - 用于调试信息
export CYAN='\033[0;36m'      # 青色 - 用于步骤提示
export BOLD='\033[1m'         # 粗体
export NC='\033[0m'           # 无颜色 - 重置颜色

# --- 图标定义 ---
export ICON_INFO="ℹ️"
export ICON_SUCCESS="✅"
export ICON_WARN="⚠️"
export ICON_ERROR="❌"
export ICON_DEBUG="🔍"
export ICON_STEP="🚀"
export ICON_SUBSTEP="📋"
export ICON_WORK="⚙️"
export ICON_DOWNLOAD="📥"
export ICON_UPLOAD="📤"
export ICON_PACKAGE="📦"
export ICON_DISK="💾"
export ICON_MEMORY="🧠"
export ICON_NETWORK="🌐"
export ICON_TIME="⏱️"
export ICON_GIT="📦"
export ICON_FILE="📄"
export ICON_REPORT="📊"

# --- 全局变量 ---
export LOG_LEVEL=${LOG_LEVEL:-"INFO"}  # 默认日志级别
export DEBUG_MODE=${DEBUG_MODE:-false} # 调试模式开关
export SCRIPT_START_TIME=${SCRIPT_START_TIME:-$(date +%s)} # 脚本开始时间
export LOG_FILE=${LOG_FILE:-""} # 日志文件路径，为空则不写入文件
export ERROR_COUNT=0 # 错误计数器
export SUCCESS_COUNT=0 # 成功计数器
export WARN_COUNT=0 # 警告计数器
export FAILED_OPERATIONS=() # 失败操作列表

# =============================================================================
# 日志记录系统
# =============================================================================

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 通用日志记录函数
_log() {
    local level="$1"
    local icon="$2"
    local color="$3"
    local message="$4"
    local timestamp=$(get_timestamp)
    local log_entry="[${timestamp}][${level}] ${message}"
    
    # 控制台输出
    echo -e "${color}${icon} ${log_entry}${NC}"
    
    # 文件输出
    if [[ -n "$LOG_FILE" ]]; then
        echo "${log_entry}" >> "$LOG_FILE"
    fi
    
    # 更新计数器
    case "$level" in
        "成功") ((SUCCESS_COUNT++)) ;;
        "错误") ((ERROR_COUNT++)) ;;
        "警告") ((WARN_COUNT++)) ;;
    esac
}

# 记录信息级别日志
log_info() {
    if [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]]; then
        _log "信息" "$ICON_INFO" "$BLUE" "$1"
    fi
}

# 记录成功级别日志
log_success() {
    _log "成功" "$ICON_SUCCESS" "$GREEN" "$1"
}

# 记录警告级别日志
log_warn() {
    _log "警告" "$ICON_WARN" "$YELLOW" "$1"
}

# 记录错误级别日志
log_error() {
    _log "错误" "$ICON_ERROR" "$RED" "$1" >&2
    FAILED_OPERATIONS+=("$1")
}

# 记录调试级别日志
log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        _log "调试" "$ICON_DEBUG" "$PURPLE" "$1"
    fi
}

# 记录步骤标题
log_step() {
    echo -e "\n${CYAN}${ICON_STEP} ========== $1 ==========${NC}\n"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "\n[$(get_timestamp)][步骤] $1\n" >> "$LOG_FILE"
    fi
}

# 记录子步骤
log_substep() {
    echo -e "\n${CYAN}${ICON_SUBSTEP} --- $1 ---${NC}\n"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "\n[$(get_timestamp)][子步骤] $1\n" >> "$LOG_FILE"
    fi
}

# 记录工作进度
log_work() {
    _log "工作" "$ICON_WORK" "$BLUE" "$1"
}

# 记录时间信息
log_time() {
    _log "时间" "$ICON_TIME" "$PURPLE" "$1"
}

# =============================================================================
# 错误处理系统
# =============================================================================

# 检查命令执行状态，失败时退出
check_status() {
    local status=$?
    local message=$1
    local exit_code=${2:-1}
    
    if [ $status -ne 0 ]; then
        log_error "$message (退出码: $status)"
        exit $exit_code
    fi
}

# 检查命令执行状态，失败时记录但不退出
check_status_no_exit() {
    local status=$?
    local message=$1
    
    if [ $status -ne 0 ]; then
        log_error "$message (退出码: $status)"
        return 1
    fi
    return 0
}

# 检查文件是否存在
check_file_exists() {
    local file_path=$1
    local message=${2:-"文件不存在: $file_path"}
    
    if [ ! -f "$file_path" ]; then
        log_error "$message"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_dir_exists() {
    local dir_path=$1
    local message=${2:-"目录不存在: $dir_path"}
    
    if [ ! -d "$dir_path" ]; then
        log_error "$message"
        return 1
    fi
    return 0
}

# 检查变量是否为空
check_var_not_empty() {
    local var_name=$1
    local var_value=$2
    local message=${3:-"变量 $var_name 不能为空"}
    
    if [ -z "$var_value" ]; then
        log_error "$message"
        return 1
    fi
    return 0
}

# 检查命令是否存在
check_command_exists() {
    local cmd=$1
    local message=${2:-"命令 $cmd 不存在"}
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$message"
        return 1
    fi
    return 0
}

# 检查磁盘空间是否足够
check_disk_space() {
    local path=$1
    local required_gb=${2:-1}
    
    local free_gb=$(get_disk_free "$path")
    if [ "$free_gb" -lt "$required_gb" ]; then
        log_error "磁盘空间不足，需要至少 ${required_gb}GB，当前剩余 ${free_gb}GB"
        return 1
    fi
    return 0
}

# =============================================================================
# 系统信息函数
# =============================================================================

# 获取系统CPU核心数
get_cpu_cores() {
    nproc
}

# 获取系统内存大小(MB)
get_memory_mb() {
    free -m | awk 'NR==2{print $2}'
}

# 获取磁盘使用情况
get_disk_usage() {
    local path=${1:-"/"}
    df -h "$path" | awk 'NR==2{print $5}'
}

# 获取磁盘剩余空间(GB)
get_disk_free() {
    local path=${1:-"/"}
    df -BG "$path" | awk 'NR==2{print $4}' | sed 's/G//'
}

# 显示系统资源使用情况
show_system_resources() {
    echo -e "${BLUE}${ICON_DISK} 系统资源使用情况:${NC}"
    echo -e "  CPU核心数: ${CYAN}$(get_cpu_cores)${NC}"
    echo -e "  内存总量: ${CYAN}$(get_memory_mb)MB${NC}"
    echo -e "  磁盘使用: ${CYAN}$(get_disk_usage)${NC}"
    echo -e "  磁盘剩余: ${CYAN}$(get_disk_free)GB${NC}"
}

# =============================================================================
# 文件操作函数
# =============================================================================

# 安全地创建目录
safe_mkdir() {
    local dir_path=$1
    local mode=${2:-755}
    
    if [ ! -d "$dir_path" ]; then
        if mkdir -p "$dir_path" && chmod "$mode" "$dir_path"; then
            log_debug "创建目录: $dir_path (权限: $mode)"
            return 0
        else
            log_error "创建目录失败: $dir_path"
            return 1
        fi
    else
        log_debug "目录已存在: $dir_path"
        return 0
    fi
}

# 安全地备份文件
safe_backup() {
    local file_path=$1
    local backup_suffix=${2:-".bak"}
    local backup_path="${file_path}${backup_suffix}"
    
    if [ -f "$file_path" ]; then
        if cp "$file_path" "$backup_path"; then
            log_debug "备份文件: $file_path -> $backup_path"
            return 0
        else
            log_error "备份文件失败: $file_path"
            return 1
        fi
    else
        log_warn "文件不存在，跳过备份: $file_path"
        return 1
    fi
}

# 安全地替换文件内容
safe_replace() {
    local file_path=$1
    local search_pattern=$2
    local replacement=$3
    local backup_suffix=${4:-".bak"}
    
    if [ -f "$file_path" ]; then
        if safe_backup "$file_path" "$backup_suffix"; then
            if sed -i "s/$search_pattern/$replacement/g" "$file_path"; then
                log_debug "替换文件内容: $file_path (搜索: $search_pattern, 替换: $replacement)"
                return 0
            else
                log_error "替换文件内容失败: $file_path"
                return 1
            fi
        else
            return 1
        fi
    else
        log_warn "文件不存在，跳过替换: $file_path"
        return 1
    fi
}

# 安全地删除文件或目录
safe_remove() {
    local path=$1
    local is_recursive=${2:-false}
    
    if [ -f "$path" ]; then
        if rm -f "$path"; then
            log_debug "删除文件: $path"
            return 0
        else
            log_error "删除文件失败: $path"
            return 1
        fi
    elif [ -d "$path" ]; then
        if [ "$is_recursive" = "true" ]; then
            if rm -rf "$path"; then
                log_debug "递归删除目录: $path"
                return 0
            else
                log_error "递归删除目录失败: $path"
                return 1
            fi
        else
            if rmdir "$path" 2>/dev/null; then
                log_debug "删除空目录: $path"
                return 0
            else
                log_warn "目录非空，无法删除: $path"
                return 1
            fi
        fi
    else
        log_debug "路径不存在，跳过删除: $path"
        return 0
    fi
}

# 安全地复制文件或目录
safe_copy() {
    local src=$1
    local dst=$2
    local is_recursive=${3:-false}
    
    if [ -f "$src" ]; then
        if cp "$src" "$dst"; then
            log_debug "复制文件: $src -> $dst"
            return 0
        else
            log_error "复制文件失败: $src -> $dst"
            return 1
        fi
    elif [ -d "$src" ]; then
        if [ "$is_recursive" = "true" ]; then
            if cp -r "$src" "$dst"; then
                log_debug "递归复制目录: $src -> $dst"
                return 0
            else
                log_error "递归复制目录失败: $src -> $dst"
                return 1
            fi
        else
            log_warn "目录复制需要递归标志: $src"
            return 1
        fi
    else
        log_error "源路径不存在: $src"
        return 1
    fi
}

# =============================================================================
# Git 操作函数
# =============================================================================

# 克隆仓库
git_clone() {
    local repo_url=$1
    local target_dir=$2
    local branch=${3:-"master"}
    
    log_work "${ICON_GIT} 克隆仓库: $repo_url (分支: $branch)"
    
    if [ -d "$target_dir" ]; then
        log_warn "目标目录已存在，跳过克隆: $target_dir"
        return 0
    fi
    
    if git clone -b "$branch" "$repo_url" "$target_dir"; then
        log_success "仓库克隆成功: $target_dir"
        return 0
    else
        log_error "仓库克隆失败: $repo_url"
        return 1
    fi
}

# 更新仓库
git_pull() {
    local repo_dir=$1
    local branch=${2:-"master"}
    
    log_work "${ICON_GIT} 更新仓库: $repo_dir (分支: $branch)"
    
    if [ ! -d "$repo_dir" ]; then
        log_error "仓库目录不存在: $repo_dir"
        return 1
    fi
    
    cd "$repo_dir" || return 1
    
    if git fetch origin && git checkout "$branch" && git pull origin "$branch"; then
        log_success "仓库更新成功: $repo_dir"
        return 0
    else
        log_error "仓库更新失败: $repo_dir"
        return 1
    fi
}

# =============================================================================
# 网络操作函数
# =============================================================================

# 检查网络连接
check_network() {
    local host=${1:-"8.8.8.8"}
    local timeout=${2:-5}
    
    log_debug "${ICON_NETWORK} 检查网络连接 (主机: $host, 超时: ${timeout}秒)"
    
    if ping -c 1 -W "$timeout" "$host" &>/dev/null; then
        log_debug "网络连接正常"
        return 0
    else
        log_debug "网络连接异常"
        return 1
    fi
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    local timeout=${3:-30}
    
    log_work "${ICON_DOWNLOAD} 下载文件: $url -> $output"
    
    if command -v wget &> /dev/null; then
        if wget --timeout="$timeout" --tries=3 -O "$output" "$url"; then
            log_success "下载成功: $output"
            return 0
        else
            log_error "下载失败: $url"
            return 1
        fi
    elif command -v curl &> /dev/null; then
        if curl --connect-timeout "$timeout" --max-time "$((timeout * 2))" -o "$output" "$url"; then
            log_success "下载成功: $output"
            return 0
        else
            log_error "下载失败: $url"
            return 1
        fi
    else
        log_error "未找到下载工具 (wget/curl)"
        return 1
    fi
}

# =============================================================================
# 配置文件处理函数
# =============================================================================

# 从配置文件中提取值
get_config_value() {
    local config_file=$1
    local key_pattern=$2
    local default_value=${3:-""}
    
    if [ -f "$config_file" ]; then
        local value=$(grep -oE "$key_pattern" "$config_file" | head -1)
        if [ -n "$value" ]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        echo "$default_value"
    fi
}

# 从配置文件中提取多个值
get_config_values() {
    local config_file=$1
    local key_pattern=$2
    
    if [ -f "$config_file" ]; then
        grep -oE "$key_pattern" "$config_file"
    fi
}

# 从配置文件中提取启用的LUCI软件包
get_enabled_luci_packages() {
    local config_file=$1
    
    if [ -f "$config_file" ]; then
        grep "^[^#].*CONFIG_PACKAGE_luci-app.*=y$" "$config_file" | \
        grep -v "_INCLUDE_" | \
        sed 's/^[^#]*CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
        sort
    fi
}

# 从配置文件中提取设备配置（修正版）
extract_device_configs() {
    local config_file=$1
    
    if [ -f "$config_file" ]; then
        grep "^CONFIG_TARGET_DEVICE_.*=y$" "$config_file" | \
        sed -r 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_(.*)=y$/\1/' | \
        sort -u
    fi
}

# 检查并删除冲突的软件包
check_and_remove_conflicting_packages() {
    local package_name=$1
    local package_dir=$2
    
    log_debug "检查冲突的软件包: $package_name"
    
    # 检查官方feeds中是否存在同名软件包
    local conflicts=()
    
    # 检查package/feeds目录
    if [ -d "package/feeds" ]; then
        local found_in_feeds=$(find package/feeds -name "$package_name" -type d 2>/dev/null)
        if [ -n "$found_in_feeds" ]; then
            conflicts+=("$found_in_feeds")
        fi
    fi
    
    # 检查feeds目录
    if [ -d "feeds" ]; then
        local found_in_feeds=$(find feeds -name "$package_name" -type d 2>/dev/null)
        if [ -n "$found_in_feeds" ]; then
            conflicts+=("$found_in_feeds")
        fi
    fi
    
    # 如果有冲突，删除它们
    if [ ${#conflicts[@]} -gt 0 ]; then
        log_warn "发现冲突的软件包，正在删除..."
        for conflict in "${conflicts[@]}"; do
            log_debug "删除冲突软件包: $conflict"
            safe_remove "$conflict" true
        done
        log_success "已删除所有冲突的软件包"
    else
        log_debug "未发现冲突的软件包"
    fi
    
    return 0
}

# =============================================================================
# 字符串处理函数
# =============================================================================

# 去除字符串首尾空格
trim() {
    local var=$1
    echo "${var}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# 检查字符串是否包含子字符串
contains() {
    local string=$1
    local substring=$2
    
    if [[ "$string" == *"$substring"* ]]; then
        return 0  # 包含
    else
        return 1  # 不包含
    fi
}

# =============================================================================
# 时间和日期函数
# =============================================================================

# 获取当前日期
get_date() {
    date '+%Y-%m-%d'
}

# 格式化持续时间
format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}小时${minutes}分${seconds}秒"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}分${seconds}秒"
    else
        echo "${seconds}秒"
    fi
}

# =============================================================================
# 用户交互函数
# =============================================================================

# 确认提示
confirm() {
    local message=$1
    local default=${2:-"n"}  # 默认为否
    
    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    read -p "$message $prompt: " -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0  # 是
            ;;
        *)
            return 1  # 否
            ;;
    esac
}

# =============================================================================
# 摘要报告函数
# =============================================================================

# 生成操作摘要报告
generate_summary() {
    local title=$1
    local start_time=${2:-$SCRIPT_START_TIME}
    local end_time=${3:-$(date +%s)}
    local status=${4:-"成功"}
    
    local duration=$((end_time - start_time))
    local formatted_duration=$(format_duration $duration)
    
    echo -e "\n${CYAN}${ICON_REPORT} ========== $title 摘要 ==========${NC}"
    echo -e "状态: ${GREEN}$status${NC}"
    echo -e "开始时间: $(date -d @$start_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "结束时间: $(date -d @$end_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "耗时: ${formatted_duration}"
    echo -e "成功操作: ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "失败操作: ${RED}$ERROR_COUNT${NC}"
    echo -e "警告操作: ${YELLOW}$WARN_COUNT${NC}"
    echo -e "磁盘剩余空间: $(get_disk_free)GB"
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "\n${RED}失败的操作列表:${NC}"
        for operation in "${FAILED_OPERATIONS[@]}"; do
            echo -e "  - $operation"
        done
    fi
    
    echo -e "${CYAN}=================================${NC}\n"
}

# =============================================================================
# OpenWrt特定函数
# =============================================================================

# 检查OpenWrt环境
check_openwrt_env() {
    local openwrt_root=${1:-"."}
    
    check_dir_exists "$openwrt_root" "OpenWrt根目录不存在: $openwrt_root" || return 1
    check_file_exists "$openwrt_root/Makefile" "OpenWrt Makefile不存在，可能不是有效的OpenWrt源码目录" || return 1
    
    log_success "OpenWrt环境检查通过"
    return 0
}

# 提取设备配置信息
extract_device_info() {
    local config_file=$1
    local output_file=${2:-"device_info.txt"}
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 提取目标架构
    local target=$(grep "^CONFIG_TARGET_.*=y$" "$config_file" | head -1 | sed 's/^CONFIG_TARGET_\(.*\)=y$/\1/' | cut -d'_' -f1)
    
    # 提取子目标
    local subtarget=$(grep "^CONFIG_TARGET_${target}_.*=y$" "$config_file" | head -1 | sed "s/^CONFIG_TARGET_${target}_\(.*\)=y$/\1/" | cut -d'_' -f1)
    
    # 提取设备名称
    local devices=$(extract_device_configs "$config_file")
    
    {
        echo "TARGET=$target"
        echo "SUBTARGET=$subtarget"
        echo "DEVICES=\"$devices\""
    } > "$output_file"
    
    log_info "设备配置信息已保存到: $output_file"
    log_debug "目标架构: $target"
    log_debug "子目标: $subtarget"
    log_debug "设备列表: $devices"
}

# =============================================================================
# 缓存管理函数
# =============================================================================

# 清理系统缓存
clear_system_cache() {
    log_info "清理系统缓存..."
    
    # 清理包管理器缓存
    if command -v apt-get &> /dev/null; then
        apt-get clean
        log_debug "已清理apt-get缓存"
    fi
    
    # 清理临时文件
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    log_debug "已清理临时文件"
    
    # 清理日志文件
    find /var/log -type f -name "*.log" -atime +7 -delete 2>/dev/null || true
    log_debug "已清理旧日志文件"
    
    log_success "系统缓存清理完成"
}
