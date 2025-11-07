#!/bin/bash

# ==============================================================================
# LUCI 软件包变更报告生成脚本
#
# 功能:
#   生成LUCI软件包差异报告
#   对比配置文件中的软件包与实际可用的软件包
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：20251107
# 版本: 1.0 - 初始版本
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 配置文件路径
CONFIG_FILE="${1:-configs/immu.config}"
# 报告输出文件
REPORT_FILE="luci_packages_report.txt"

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "LUCI 软件包变更报告生成脚本"
    log_info "作者: Mary"
    log_info "版本: 1.0 - 初始版本"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查环境
check_environment() {
    log_info "检查执行环境..."
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        return 1
    fi
    
    log_success "环境检查通过"
    return 0
}

# 从配置文件中提取LUCI软件包列表
extract_luci_packages_from_config() {
    log_info "从配置文件提取LUCI软件包列表: $CONFIG_FILE"
    
    # 提取不以#开头且以=y结尾的luci-app软件包
    local packages
    packages=$(grep "^CONFIG_PACKAGE_luci-app.*=y$" "$CONFIG_FILE" | sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | sort)
    
    if [ -z "$packages" ]; then
        log_warning "未找到LUCI软件包配置"
        return 1
    fi
    
    echo "$packages"
    return 0
}

# 获取可用的LUCI软件包列表
get_available_luci_packages() {
    log_info "获取可用的LUCI软件包列表..."
    
    # 更新软件包索引
    log_info "更新软件包索引..."
    make defconfig > /dev/null 2>&1
    
    # 获取可用的LUCI软件包列表
    local available_packages
    available_packages=$(find package feeds -name "luci-app-*" -type d | sed 's/.*\///' | sort -u)
    
    if [ -z "$available_packages" ]; then
        log_warning "未找到可用的LUCI软件包"
        return 1
    fi
    
    echo "$available_packages"
    return 0
}

# 生成软件包差异报告
generate_package_diff_report() {
    local config_packages="$1"
    local available_packages="$2"
    
    log_info "生成软件包差异报告..."
    
    # 创建临时文件
    local config_packages_file=$(mktemp)
    local available_packages_file=$(mktemp)
    
    # 写入临时文件
    echo "$config_packages" > "$config_packages_file"
    echo "$available_packages" > "$available_packages_file"
    
    # 生成报告
    {
        echo "=================================================================="
        echo "LUCI 软件包差异报告"
        echo "=================================================================="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "配置文件: $CONFIG_FILE"
        echo ""
        
        # 配置文件中的软件包
        echo "配置文件中的软件包 (共 $(wc -l < "$config_packages_file") 个):"
        echo "----------------------------------------"
        cat "$config_packages_file"
        echo ""
        
        # 可用的软件包
        echo "可用的软件包 (共 $(wc -l < "$available_packages_file") 个):"
        echo "----------------------------------------"
        cat "$available_packages_file"
        echo ""
        
        # 新增的软件包（可用但未在配置中）
        echo "新增的软件包 (可用但未在配置中):"
        echo "----------------------------------------"
        comm -13 "$config_packages_file" "$available_packages_file"
        echo ""
        
        # 移除的软件包（在配置中但不可用）
        echo "移除的软件包 (在配置中但不可用):"
        echo "----------------------------------------"
        comm -23 "$config_packages_file" "$available_packages_file"
        echo ""
        
        # 共同的软件包
        echo "共同的软件包 (在配置中且可用):"
        echo "----------------------------------------"
        comm -12 "$config_packages_file" "$available_packages_file"
        echo ""
        
        echo "=================================================================="
    } > "$REPORT_FILE"
    
    # 清理临时文件
    rm -f "$config_packages_file" "$available_packages_file"
    
    log_success "软件包差异报告生成完成: $REPORT_FILE"
    
    # 显示报告内容
    if [ "${SHOW_REPORT:-1}" = "1" ]; then
        cat "$REPORT_FILE"
    fi
    
    return 0
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    show_execution_summary
    
    echo ""
    echo "报告文件: $REPORT_FILE"
    echo ""
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
        # 从配置文件中提取LUCI软件包列表
        local config_packages
        config_packages=$(extract_luci_packages_from_config)
        
        # 获取可用的LUCI软件包列表
        local available_packages
        available_packages=$(get_available_luci_packages)
        
        # 生成软件包差异报告
        if [ -n "$config_packages" ] && [ -n "$available_packages" ]; then
            generate_package_diff_report "$config_packages" "$available_packages"
        else
            log_error "无法获取软件包列表，无法生成报告"
            exit 1
        fi
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"
