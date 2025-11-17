#!/bin/bash

# ==============================================================================
# OpenWrt/ImmortalWrt 自定义配置脚本
#
# 功能:
#   配置设备初始管理IP/密码
#   应用自定义配置
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 3.1 - 修复版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 默认IP地址
DEFAULT_IP="192.168.111.1"
# 默认密码（空）
DEFAULT_PASSWORD=""
# 默认主机名
DEFAULT_HOSTNAME="WRT"
# 默认主题
DEFAULT_THEME="argon"

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

# --- 统计变量 ---
SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt/ImmortalWrt 自定义配置脚本"
    log_info "作者: Mary"
    log_info "版本: 3.1 - 修复版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
}

# 检查环境
check_environment() {
    log_processing "检查执行环境..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    log_success "环境检查通过"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 配置初始IP和密码
configure_initial_settings() {
    log_processing "配置初始IP和密码..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    local ip="${1:-$DEFAULT_IP}"
    local password="${2:-$DEFAULT_PASSWORD}"
    local hostname="${3:-$DEFAULT_HOSTNAME}"
    
    # 修改默认IP
    log_info "设置默认IP: $ip"
    if sed -i "s/192.168.1.1/$ip/g" package/base-files/files/bin/config_generate; then
        log_success "IP设置成功"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log_error "IP设置失败"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    # 设置主机名
    log_info "设置主机名: $hostname"
    if sed -i "s/OpenWrt/$hostname/g" package/base-files/files/bin/config_generate; then
        log_success "主机名设置成功"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log_error "主机名设置失败"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
    
    # 生成密码哈希（如果密码不为空）
    if [ -n "$password" ]; then
        log_info "设置默认密码"
        local password_hash
        password_hash=$(openssl passwd -1 "$password")
        if sed -i "s/root:::0:99999:7:::/root:$password_hash:18579:0:99999:7:::/g" package/base-files/files/etc/shadow; then
            log_success "密码设置成功"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log_error "密码设置失败"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    else
        log_info "设置空密码（无密码登录）"
        if sed -i "s/root:::0:99999:7:::/root:::0:99999:7:::/g" package/base-files/files/etc/shadow; then
            log_success "空密码设置成功"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            log_error "空密码设置失败"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            return 1
        fi
    fi
    
    log_success "初始IP和密码配置完成"
    return 0
}

# 应用自定义配置
apply_custom_configurations() {
    log_processing "应用自定义配置..."
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # 这里可以添加其他自定义配置
    
    log_success "自定义配置应用完成"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    return 0
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
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
        # 配置初始IP和密码
        configure_initial_settings "$@"
        
        # 应用自定义配置
        apply_custom_configurations
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        generate_final_summary
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"
