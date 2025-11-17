#!/bin/bash

# ==============================================================================
# Luci软件包差异报告生成脚本
#
# 功能:
#   生成Luci软件包差异报告
#   对比配置文件中的Luci软件包与实际安装的软件包
#
# 使用方法:
#   在OpenWrt/ImmortalWrt源码根目录下运行此脚本
#
# 作者: Mary
# 日期：2025-11-17
# 版本: 1.0
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 主函数 ---
main() {
    log_step "生成Luci软件包差异报告"
    
    # 从配置文件中提取Luci软件包
    log_processing "从配置文件中提取Luci软件包"
    local config_luci_packages=$(grep "^CONFIG_PACKAGE_luci-.*=y" .config | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort)
    
    # 获取实际安装的Luci软件包
    log_processing "获取实际安装的Luci软件包"
    local installed_luci_packages=$(find ./feeds/luci/collections -name "*.mk" -exec grep -l "Package:" {} \; | xargs -I {} grep "Package:" {} | sed 's/.*Package:[[:space:]]*\(luci-.*\)/\1/' | sort -u)
    
    # 获取已安装的Luci应用软件包
    log_processing "获取已安装的Luci应用软件包"
    local installed_packages=$(find ./feeds/luci/applications -name "Makefile" -exec grep -l "Package:" {} \; | xargs -I {} grep "Package:" {} | sed 's/.*Package:[[:space:]]*\(luci-.*\)/\1/' | sort -u)
    
    # 合并已安装的软件包
    local all_installed_packages=$(echo -e "$installed_luci_packages\n$installed_packages" | sort -u)
    
    # 计算差异
    log_processing "计算软件包差异"
    local missing_packages=$(comm -23 <(echo "$config_luci_packages") <(echo "$all_installed_packages"))
    local extra_packages=$(comm -13 <(echo "$config_luci_packages") <(echo "$all_installed_packages"))
    
    # 输出报告
    echo "========================================"
    echo "Luci软件包差异报告"
    echo "========================================"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "配置文件中的Luci软件包数量: $(echo "$config_luci_packages" | wc -l)"
    echo "实际安装的Luci软件包数量: $(echo "$all_installed_packages" | wc -l)"
    echo ""
    
    if [ -n "$missing_packages" ]; then
        echo "缺失的Luci软件包:"
        echo "$missing_packages"
        echo ""
    else
        echo "没有缺失的Luci软件包"
        echo ""
    fi
    
    if [ -n "$extra_packages" ]; then
        echo "额外的Luci软件包:"
        echo "$extra_packages"
        echo ""
    else
        echo "没有额外的Luci软件包"
        echo ""
    
... (还有17个字符未显示)
