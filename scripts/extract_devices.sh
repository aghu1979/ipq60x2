#!/bin/bash

# ==============================================================================
# 从配置文件中提取设备名称脚本
#
# 功能:
#   从配置文件中提取设备名称
#   剔除重复项
#
# 使用方法:
#   ./extract_devices.sh <配置文件路径>
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 1.0
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 主函数 ---
main() {
    local config_file="$1"
    
    if [ -z "$config_file" ]; then
        log_error "请提供配置文件路径"
        exit 1
    fi
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        exit 1
    fi
    
    log_step "从配置文件中提取设备名称"
    log_info "配置文件: $config_file"
    
    # 从配置文件中提取设备名称
    local device_names=$(grep "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$config_file" | sed 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_\(.*\)=y/\1/' | sort -u)
    
    if [ -z "$device_names" ]; then
        log_warning "未找到设备名称"
        exit 1
    fi
    
    log_success "提取到的设备名称:"
    for device in $device_names; do
        echo -e "${COLOR_GREEN}  - $device${COLOR_RESET}"
    done
    
    # 输出为环境变量格式
    echo -e "${COLOR_CYAN}环境变量格式:${COLOR_RESET}"
    echo -n "DEVICE_NAMES=\""
    first=true
    for device in $device_names; do
        if [ "$first" = true ]; then
            echo -n "$device"
            first=false
        else
            echo -n " $device"
        fi
    done
    echo "\""
    
    return 0
}

# 执行主函数
main "$@"
