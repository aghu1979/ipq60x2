#!/bin/bash
# 公共函数库
# 提供通用的工具函数

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $*"
    fi
}

# 错误处理函数
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在且可读
check_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        error_exit "文件不存在: $file"
    fi
    if [[ ! -r "$file" ]]; then
        error_exit "文件不可读: $file"
    fi
}

# 检查目录是否存在
check_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        error_exit "目录不存在: $dir"
    fi
}

# 创建目录（如果不存在）
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || error_exit "无法创建目录: $dir"
        log_info "创建目录: $dir"
    fi
}

# 获取CPU核心数
get_cpu_cores() {
    if command_exists nproc; then
        nproc
    else
        echo 1
    fi
}

# 获取系统内存大小（GB）
get_memory_gb() {
    if [[ -f /proc/meminfo ]]; then
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024 / 1024))
    else
        echo 1
    fi
}

# 计算合适的编译线程数
calc_make_jobs() {
    local cpu_cores=$(get_cpu_cores)
    local memory_gb=$(get_memory_gb)
    
    # 每个编译任务大约需要1.5GB内存
    local max_jobs_by_mem=$((memory_gb * 2 / 3))
    local jobs=$((cpu_cores < max_jobs_by_mem ? cpu_cores : max_jobs_by_mem))
    
    # 至少使用1个线程，最多不超过CPU核心数
    if [[ $jobs -lt 1 ]]; then
        jobs=1
    elif [[ $jobs -gt $cpu_cores ]]; then
        jobs=$cpu_cores
    fi
    
    echo $jobs
}

# 检查磁盘空间
check_disk_space() {
    local path="$1"
    local required_gb="$2"
    
    local available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [[ $available_gb -lt $required_gb ]]; then
        error_exit "磁盘空间不足。需要: ${required_gb}GB, 可用: ${available_gb}GB"
    fi
}

# 清理函数
cleanup_on_exit() {
    log_info "执行清理操作..."
    # 这里可以添加清理逻辑
}

# 设置陷阱
trap cleanup_on_exit EXIT

# 进度条函数
show_progress() {
    local current="$1"
    local total="$2"
    local desc="$3"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[%s]${NC} [" "$desc"
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percent $current $total
}

# 等待函数
wait_for_process() {
    local pid="$1"
    local timeout="${2:-300}"
    local interval="${3:-5}"
    
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            kill "$pid" 2>/dev/null || true
            error_exit "进程超时: $pid"
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    wait "$pid"
    return $?
}

# 版本比较函数
version_compare() {
    local version1="$1"
    local version2="$2"
    
    if [[ $version1 == $version2 ]]; then
        echo 0
    else
        local IFS=.
        local i ver1=($version1) ver2=($version2)
        
        for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
            ver1[i]=0
        done
        
        for ((i=0; i<${#ver1[@]}; i++)); do
            if [[ -z ${ver2[i]} ]]; then
                ver2[i]=0
            fi
            
            if ((10#${ver1[i]} > 10#${ver2[i]})); then
                echo 1
                return
            fi
            
            if ((10#${ver1[i]} < 10#${ver2[i]})); then
                echo -1
                return
            fi
        done
        
        echo 0
    fi
}

# 生成随机字符串
generate_random_string() {
    local length="${1:-16}"
    if command_exists openssl; then
        openssl rand -hex $((length / 2))
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
    fi
}

# 检查网络连接
check_network() {
    local url="${1:-https://www.google.com}"
    local timeout="${2:-10}"
    
    if command_exists curl; then
        curl -s --connect-timeout "$timeout" "$url" >/dev/null
    elif command_exists wget; then
        wget -q --timeout="$timeout" --tries=1 "$url" -O /dev/null
    else
        ping -c 1 -W "$timeout" 8.8.8.8 >/dev/null
    fi
}

# 导出所有函数
export -f log_info log_warn log_error log_debug
export -f error_exit command_exists check_file check_dir
export -f ensure_dir get_cpu_cores get_memory_gb calc_make_jobs
export -f check_disk_space show_progress wait_for_process
export -f version_compare generate_random_string check_network
