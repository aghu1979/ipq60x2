# scripts/common.sh
#!/bin/bash

# ==============================================================================
# 通用函数库
# 
# 功能:
#   提供通用的日志记录、错误处理、文件操作等功能
#   为其他脚本提供基础支持
#
# 作者: Mary
# 日期：20251104
# ==============================================================================

# --- 颜色定义 ---
export RED='\033[0;31m'       # 红色 - 用于错误信息
export GREEN='\033[0;32m'     # 绿色 - 用于成功信息
export YELLOW='\033[1;33m'    # 黄色 - 用于警告信息
export BLUE='\033[0;34m'      # 蓝色 - 用于信息提示
export PURPLE='\033[0;35m'    # 紫色 - 用于调试信息
export CYAN='\033[0;36m'      # 青色 - 用于步骤提示
export BOLD='\033[1m'         # 粗体
export NC='\033[0m'           # 无颜色 - 重置颜色

# --- 全局变量 ---
export LOG_LEVEL=${LOG_LEVEL:-"INFO"}  # 默认日志级别
export DEBUG_MODE=${DEBUG_MODE:-false} # 调试模式开关
export SCRIPT_START_TIME=${SCRIPT_START_TIME:-$(date +%s)} # 脚本开始时间

# --- 系统信息函数 ---
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
    echo -e "${BLUE}系统资源使用情况:${NC}"
    echo -e "  CPU核心数: ${CYAN}$(get_cpu_cores)${NC}"
    echo -e "  内存总量: ${CYAN}$(get_memory_mb)MB${NC}"
    echo -e "  磁盘使用: ${CYAN}$(get_disk_usage)${NC}"
    echo -e "  磁盘剩余: ${CYAN}$(get_disk_free)GB${NC}"
}

# --- 日志记录函数 ---
# 记录信息级别日志
log_info() {
    if [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${BLUE}[$(get_timestamp)][信息]${NC} $1"
    fi
}

# 记录成功级别日志
log_success() {
    echo -e "${GREEN}[$(get_timestamp)][成功]${NC} $1"
}

# 记录警告级别日志
log_warn() {
    echo -e "${YELLOW}[$(get_timestamp)][警告]${NC} $1"
}

# 记录错误级别日志
log_error() {
    echo -e "${RED}[$(get_timestamp)][错误]${NC} $1" >&2
}

# 记录调试级别日志
log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${PURPLE}[$(get_timestamp)][调试]${NC} $1"
    fi
}

# 记录步骤标题
log_step() {
    echo -e "\n${CYAN}========== $1 ==========${NC}\n"
}

# 记录子步骤
log_substep() {
    echo -e "\n${CYAN}--- $1 ---${NC}\n"
}

# --- 错误处理函数 ---
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

# 检查文件是否存在，不存在时退出
check_file_exists() {
    local file_path=$1
    local message=${2:-"文件不存在: $file_path"}
    
    if [ ! -f "$file_path" ]; then
        log_error "$message"
        exit 1
    fi
}

# 检查目录是否存在，不存在时退出
check_dir_exists() {
    local dir_path=$1
    local message=${2:-"目录不存在: $dir_path"}
    
    if [ ! -d "$dir_path" ]; then
        log_error "$message"
        exit 1
    fi
}

# 检查变量是否为空，为空时退出
check_var_not_empty() {
    local var_name=$1
    local var_value=$2
    local message=${3:-"变量 $var_name 不能为空"}
    
    if [ -z "$var_value" ]; then
        log_error "$message"
        exit 1
    fi
}

# 检查命令是否存在
check_command_exists() {
    local cmd=$1
    local message=${2:-"命令 $cmd 不存在"}
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$message"
        exit 1
    fi
}

# --- 文件操作函数 ---
# 安全地创建目录
safe_mkdir() {
    local dir_path=$1
    local mode=${2:-755}
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        chmod "$mode" "$dir_path"
        log_debug "创建目录: $dir_path (权限: $mode)"
    fi
}

# 安全地备份文件
safe_backup() {
    local file_path=$1
    local backup_suffix=${2:-".bak"}
    
    if [ -f "$file_path" ]; then
        cp "$file_path" "${file_path}${backup_suffix}"
        log_debug "备份文件: $file_path -> ${file_path}${backup_suffix}"
    fi
}

# 安全地替换文件内容
safe_replace() {
    local file_path=$1
    local search_pattern=$2
    local replacement=$3
    local backup_suffix=${4:-".bak"}
    
    if [ -f "$file_path" ]; then
        safe_backup "$file_path" "$backup_suffix"
        sed -i "s/$search_pattern/$replacement/g" "$file_path"
        log_debug "替换文件内容: $file_path (搜索: $search_pattern, 替换: $replacement)"
    else
        log_warn "文件不存在，跳过替换: $file_path"
    fi
}

# 安全地删除文件或目录
safe_remove() {
    local path=$1
    local is_recursive=${2:-false}
    
    if [ -f "$path" ]; then
        rm -f "$path"
        log_debug "删除文件: $path"
    elif [ -d "$path" ]; then
        if [ "$is_recursive" = "true" ]; then
            rm -rf "$path"
            log_debug "递归删除目录: $path"
        else
            rmdir "$path" 2>/dev/null || log_warn "目录非空，无法删除: $path"
        fi
    else
        log_debug "路径不存在，跳过删除: $path"
    fi
}

# 安全地复制文件或目录
safe_copy() {
    local src=$1
    local dst=$2
    local is_recursive=${3:-false}
    
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        log_debug "复制文件: $src -> $dst"
    elif [ -d "$src" ]; then
        if [ "$is_recursive" = "true" ]; then
            cp -r "$src" "$dst"
            log_debug "递归复制目录: $src -> $dst"
        else
            log_warn "目录复制需要递归标志: $src"
        fi
    else
        log_error "源路径不存在: $src"
        exit 1
    fi
}

# --- 字符串处理函数 ---
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

# --- 配置文件处理函数 ---
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
        grep "^CONFIG_PACKAGE_luci-app.*=y$" "$config_file" | \
        grep -v "_INCLUDE_" | \
        sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | \
        sort
    fi
}

# 从配置文件中提取设备配置
extract_device_configs() {
    local config_file=$1
    
    if [ -f "$config_file" ]; then
        grep "^CONFIG_TARGET.*DEVICE.*=y$" "$config_file" | \
        sed -r 's/.*DEVICE_(.*)=y/\1/'
    fi
}

# --- 时间和日期函数 ---
# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

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

# --- 进程和任务函数 ---
# 等待进程完成
wait_for_process() {
    local pid=$1
    local timeout=${2:-300}  # 默认超时5分钟
    local interval=${3:-5}   # 默认检查间隔5秒
    local elapsed=0
    
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$elapsed" -ge "$timeout" ]; then
            log_error "等待进程超时 (PID: $pid)"
            return 1
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 0
}

# --- 网络函数 ---
# 检查网络连接
check_network() {
    local host=${1:-"8.8.8.8"}
    local timeout=${2:-5}
    
    if ping -c 1 -W "$timeout" "$host" &>/dev/null; then
        return 0  # 网络正常
    else
        return 1  # 网络异常
    fi
}

# --- 用户交互函数 ---
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

# --- 摘要报告函数 ---
# 生成操作摘要报告
generate_summary() {
    local title=$1
    local start_time=${2:-$SCRIPT_START_TIME}
    local end_time=${3:-$(date +%s)}
    local status=${4:-"成功"}
    
    local duration=$((end_time - start_time))
    local formatted_duration=$(format_duration $duration)
    
    echo -e "\n${CYAN}========== $title 摘要 ==========${NC}"
    echo -e "状态: ${GREEN}$status${NC}"
    echo -e "开始时间: $(date -d @$start_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "结束时间: $(date -d @$end_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "耗时: ${formatted_duration}"
    echo -e "磁盘剩余空间: $(get_disk_free)GB"
    echo -e "${CYAN}=================================${NC}\n"
}

# --- 缓存管理函数 ---
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

# --- OpenWrt特定函数 ---
# 检查OpenWrt环境
check_openwrt_env() {
    local openwrt_root=${1:-"."}
    
    check_dir_exists "$openwrt_root" "OpenWrt根目录不存在: $openwrt_root"
    check_file_exists "$openwrt_root/Makefile" "OpenWrt Makefile不存在，可能不是有效的OpenWrt源码目录"
    
    log_success "OpenWrt环境检查通过"
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
