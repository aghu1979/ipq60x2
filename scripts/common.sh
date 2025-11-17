#!/bin/bash

# ==============================================================================
# OpenWrt/ImmortalWrt 通用函数库
#
# 功能:
#   提供通用的日志函数、错误处理函数等
#
# 使用方法:
#   在其他脚本中通过 source 命令导入此脚本
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 1.0
# ==============================================================================

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

log_time() {
    echo -e "${COLOR_WHITE}[TIME] $1${COLOR_RESET}"
}

# --- 错误处理函数 ---
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    if [ $exit_code -ne 0 ]; then
        log_error "命令执行失败，退出码: $exit_code"
        log_error "失败命令: $command"
        log_error "所在行号: $line_number"
        exit $exit_code
    fi
}

# 设置错误处理
set -eE
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# --- 文件操作函数 ---
backup_file() {
    local file_path="$1"
    local backup_suffix="${2:-.bak}"
    
    if [ -f "$file_path" ]; then
        local backup_path="${file_path}${backup_suffix}"
        cp "$file_path" "$backup_path"
        log_success "文件备份成功: $backup_path"
        return 0
    else
        log_warning "文件不存在，无法备份: $file_path"
        return 1
    fi
}

# --- 磁盘空间检查函数 ---
check_disk_space() {
    local threshold="${1:-90}"  # 默认阈值为90%
    local path="${2:-.}"        # 默认检查当前目录
    
    local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt "$threshold" ]; then
        log_warning "磁盘空间使用率超过阈值: ${usage}% > ${threshold}%"
        return 1
    else
        log_success "磁盘空间使用率正常: ${usage}% <= ${threshold}%"
        return 0
    fi
}

# --- 网络连接检查函数 ---
check_network() {
    local url="${1:-https://github.com}"
    
    if curl -s --head "$url" | grep -q "200 OK"; then
        log_success "网络连接正常: $url"
        return 0
    else
        log_error "网络连接失败: $url"
        return 1
    fi
}

# --- 执行摘要函数 ---
show_execution_summary() {
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
