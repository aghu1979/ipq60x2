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

# --- 日志记录函数 ---
# 记录信息级别日志
log_info() {
    if [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${BLUE}[信息]${NC} $1"
    fi
}

# 记录成功级别日志
log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

# 记录警告级别日志
log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 记录错误级别日志
log_error() {
    echo -e "${RED}[错误]${NC} $1" >&2
}

# 记录调试级别日志
log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${PURPLE}[调试]${NC} $1"
    fi
}

# 记录步骤标题
log_step() {
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

# --- 时间和日期函数 ---
# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 获取当前日期
get_date() {
    date '+%Y-%m-%d'
}

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
    local start_time=$2
    local end_time=${3:-$(date +%s)}
    local status=${4:-"成功"}
    
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "\n${CYAN}========== $title 摘要 ==========${NC}"
    echo -e "状态: ${GREEN}$status${NC}"
    echo -e "开始时间: $(date -d @$start_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "结束时间: $(date -d @$end_time '+%Y-%m-%d %H:%M:%S')"
    echo -e "耗时: ${minutes}分${seconds}秒"
    echo -e "${CYAN}=================================${NC}\n"
}
