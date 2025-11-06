#!/bin/bash
# =============================================================================
# ImmortalWrt 编译通用函数库
# 版本: 1.0
# 作者: Auto-generated
# 描述: 提供编译过程中常用的函数和工具
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 图标定义
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_WORK="🔧"
ICON_PACKAGE="📦"
ICON_DEVICE="📱"
ICON_DISK="💾"
ICON_TIME="⏰"

# 日志函数
log_info() {
    echo -e "${CYAN}${ICON_INFO} [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} [WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}${ICON_ERROR} [ERROR]${NC} $1"
}

log_work() {
    echo -e "${BLUE}${ICON_WORK} [WORK]${NC} $1"
}

log_package() {
    echo -e "${PURPLE}${ICON_PACKAGE} [PACKAGE]${NC} $1"
}

log_device() {
    echo -e "${WHITE}${ICON_DEVICE} [DEVICE]${NC} $1"
}

log_disk() {
    echo -e "${CYAN}${ICON_DISK} [DISK]${NC} $1"
}

log_time() {
    echo -e "${YELLOW}${ICON_TIME} [TIME]${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查磁盘空间
check_disk_space() {
    local path=${1:-"/"}
    local min_space=${2:-5} # GB
    
    local available=$(df -BG "$path" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available" -lt "$min_space" ]; then
        log_warning "磁盘空间不足: ${available}GB < ${min_space}GB"
        return 1
    else
        log_success "磁盘空间充足: ${available}GB"
        return 0
    fi
}

# 显示磁盘使用情况
show_disk_usage() {
    log_disk "当前磁盘使用情况:"
    df -h | grep -E "(Filesystem|/dev/)" | while read line; do
        echo "  $line"
    done
}

# 提取设备配置
extract_devices_from_config() {
    local config_file=${1:-".config"}
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_device "从配置文件提取设备信息..."
    
    # 提取设备名称并去重
    local devices=$(grep "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$config_file" | \
        sed 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_//g' | \
        sed 's/=y$//g' | \
        sort -u | \
        tr '\n' ' ')
    
    if [ -z "$devices" ]; then
        log_warning "未找到设备配置"
        return 1
    fi
    
    echo "$devices"
    log_success "提取到设备: $devices"
}

# 检查网络连接
check_network() {
    local url=${1:-"https://github.com"}
    
    if curl -s --connect-timeout 5 "$url" > /dev/null; then
        log_success "网络连接正常"
        return 0
    else
        log_error "网络连接失败"
        return 1
    fi
}

# 获取系统信息
get_system_info() {
    echo "系统信息:"
    echo "  操作系统: $(uname -s)"
    echo "  内核版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  CPU核心数: $(nproc)"
    echo "  内存: $(free -h | awk 'NR==2{print $2}')"
    echo "  当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 创建备份
backup_file() {
    local file=$1
    local backup_dir=${2:-"backup"}
    
    if [ ! -f "$file" ]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename $file).$(date +%Y%m%d_%H%M%S).bak"
    
    cp "$file" "$backup_file"
    log_success "备份文件: $file -> $backup_file"
}

# 清理函数
cleanup() {
    log_work "执行清理操作..."
    # 可以在这里添加具体的清理逻辑
    rm -f *.tmp
    rm -f *.log
}

# 错误处理函数
error_handler() {
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误"
    cleanup
    exit 1
}

# 设置错误陷阱
trap 'error_handler $LINENO' ERR

# 性能监控
start_time=$(date +%s)
show_elapsed_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    
    log_time "执行时间: ${hours}小时 ${minutes}分钟 ${seconds}秒"
}

# 版本比较
version_compare() {
    local version1=$1
    local version2=$2
    
    if [[ $version1 == $version2 ]]; then
        echo 0
    elif [[ $(printf '%s\n' "$version1" "$version2" | sort -V | head -n1) == $version1 ]]; then
        echo -1
    else
        echo 1
    fi
}

# 初始化函数
init_common() {
    log_info "初始化通用函数库..."
    get_system_info
    show_disk_usage
    check_network
    log_success "通用函数库初始化完成"
}

# 如果直接执行此脚本，则运行初始化
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_common
fi
