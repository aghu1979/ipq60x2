#!/bin/bash

# ==============================================================================
# LUCI 软件包变更报告生成脚本
#
# 功能:
#   生成 defconfig 前后的 LUCI 软件包详细对比报告
#   分析软件包变更情况
#   生成统计信息和差异列表
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#   ./scripts/luci_report.sh [配置文件路径]
#
# 作者: Mary
# 日期：20251107
# 版本: 2.2 - 企业级优化版
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 配置文件路径
CONFIG_FILE="${1:-configs/immu.config}"
# 报告输出目录
REPORT_DIR="reports"
# defconfig 前软件包列表
BEFORE_LIST="$REPORT_DIR/luci_packages_before.txt"
# defconfig 后软件包列表
AFTER_LIST="$REPORT_DIR/luci_packages_after.txt"
# 对比报告文件
DIFF_REPORT="$REPORT_DIR/luci_packages_diff.txt"
# 详细报告文件
DETAIL_REPORT="$REPORT_DIR/luci_packages_detail.txt"

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "LUCI 软件包变更报告生成脚本 v2.2"
    log_info "作者: Mary"
    log_info "版本: 2.2 - 企业级优化版"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "配置文件: $CONFIG_FILE"
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
    
    # 创建报告目录
    safe_mkdir "$REPORT_DIR"
    
    log_success "环境检查通过"
    return 0
}

# 从配置文件中提取启用的 LUCI 软件包
extract_enabled_luci_packages() {
    log_info "从配置文件提取启用的 LUCI 软件包"
    
    # 提取不以#开头且以=y结尾的luci-app软件包
    local enabled_packages
    enabled_packages=$(grep "^CONFIG_PACKAGE_luci-app.*=y$" "$CONFIG_FILE" | sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | sort)
    
    if [ -z "$enabled_packages" ]; then
        log_warning "未找到启用的 LUCI 软件包配置"
        return 1
    fi
    
    # 保存到文件
    echo "$enabled_packages" > "$REPORT_DIR/enabled_luci_packages.txt"
    
    local count
    count=$(wc -l < "$REPORT_DIR/enabled_luci_packages.txt")
    log_success "配置文件中启用的 LUCI 软件包数量: $count"
    
    # 显示启用的软件包列表
    log_info "启用的 LUCI 软件包列表:"
    echo "$enabled_packages" | while read -r pkg; do
        log_info "  - $pkg"
    done
    
    return 0
}

# 获取当前可用的 LUCI 软件包列表
get_current_luci_packages() {
    local list_file="$1"
    local description="$2"
    
    log_info "获取 $description"
    
    # 获取所有 luci-app 软件包
    local packages
    packages=$(find package feeds -name "luci-app-*" -type d 2>/dev/null | sed 's/.*\///' | sort -u)
    
    if [ -z "$packages" ]; then
        log_warning "未找到 LUCI 软件包"
        return 1
    fi
    
    # 保存到文件
    echo "$packages" > "$list_file"
    
    local count
    count=$(wc -l < "$list_file")
    log_success "$description 数量: $count"
    
    return 0
}

# 分析软件包状态
analyze_package_status() {
    local package="$1"
    local before_available="$2"
    local after_available="$3"
    local enabled="$4"
    
    local status=""
    local detail=""
    
    # 检查是否在配置中启用
    if echo "$enabled" | grep -q "^$package$"; then
        status="已启用"
        detail="配置文件中启用"
    else
        status="未启用"
        detail="配置文件中未启用"
    fi
    
    # 检查可用性变化
    if echo "$before_available" | grep -q "^$package$" && echo "$after_available" | grep -q "^$package$"; then
        status="$status (保持可用)"
        detail="$detail; defconfig 前后均可用"
    elif echo "$before_available" | grep -q "^$package$" && ! echo "$after_available" | grep -q "^$package$"; then
        status="$status (已移除)"
        detail="$detail; defconfig 后不可用"
    elif ! echo "$before_available" | grep -q "^$package$" && echo "$after_available" | grep -q "^$package$"; then
        status="$status (新增)"
        detail="$detail; defconfig 后新增"
    else
        status="$status (不可用)"
        detail="$detail; defconfig 前后均不可用"
    fi
    
    echo "$package|$status|$detail"
}

# 生成详细报告
generate_detailed_report() {
    log_info "生成详细软件包状态报告"
    
    # 读取各个列表
    local before_packages
    before_packages=$(cat "$BEFORE_LIST" 2>/dev/null || echo "")
    
    local after_packages
    after_packages=$(cat "$AFTER_LIST" 2>/dev/null || echo "")
    
    local enabled_packages
    enabled_packages=$(cat "$REPORT_DIR/enabled_luci_packages.txt" 2>/dev/null || echo "")
    
    # 合并所有软件包
    local all_packages
    all_packages=$(echo -e "$before_packages\n$after_packages\n$enabled_packages" | sort -u)
    
    # 生成详细报告
    {
        echo "=================================================================="
        echo "LUCI 软件包详细状态报告"
        echo "=================================================================="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "配置文件: $CONFIG_FILE"
        echo ""
        
        echo "📋 软件包状态说明:"
        echo "----------------------------------------"
        echo "- 已启用: 配置文件中启用的软件包"
        echo "- 未启用: 配置文件中未启用的软件包"
        echo "- 保持可用: defconfig 前后均可用"
        echo "- 新增: defconfig 后新增的软件包"
        echo "- 已移除: defconfig 后不可用的软件包"
        echo "- 不可用: defconfig 前后均不可用"
        echo ""
        
        echo "📊 详细软件包列表:"
        echo "----------------------------------------"
        echo "软件包名称 | 状态 | 详细说明"
        echo "---------|------|---------"
        
        for package in $all_packages; do
            local result
            result=$(analyze_package_status "$package" "$before_packages" "$after_packages" "$enabled_packages")
            echo "$result" | sed 's/|/ | /g'
        done
        echo ""
        
        echo "=================================================================="
    } > "$DETAIL_REPORT"
    
    log_success "详细报告生成完成: $DETAIL_REPORT"
}

# 生成对比报告
generate_diff_report() {
    log_info "生成软件包对比报告"
    
    # 检查文件是否存在
    if [ ! -f "$BEFORE_LIST" ] || [ ! -f "$AFTER_LIST" ]; then
        log_error "软件包列表文件不存在"
        return 1
    fi
    
    # 统计数量
    local before_count
    before_count=$(wc -l < "$BEFORE_LIST")
    
    local after_count
    after_count=$(wc -l < "$AFTER_LIST")
    
    local enabled_count
    enabled_count=$(wc -l < "$REPORT_DIR/enabled_luci_packages.txt" 2>/dev/null || echo "0")
    
    local change_count=$((after_count - before_count))
    
    # 生成对比报告
    {
        echo "=================================================================="
        echo "LUCI 软件包变更报告"
        echo "=================================================================="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "配置文件: $CONFIG_FILE"
        echo ""
        
        echo "📊 统计信息:"
        echo "----------------------------------------"
        echo "defconfig 前软件包数量: $before_count"
        echo "defconfig 后软件包数量: $after_count"
        echo "配置文件启用软件包数量: $enabled_count"
        echo "变更数量: $change_count"
        echo ""
        
        echo "📋 配置文件启用的软件包 ($enabled_count 个):"
        echo "----------------------------------------"
        if [ -f "$REPORT_DIR/enabled_luci_packages.txt" ]; then
            cat "$REPORT_DIR/enabled_luci_packages.txt" | while read -r pkg; do
                echo "  - $pkg"
            done
        else
            echo "无启用的软件包"
        fi
        echo ""
        
        echo "🆕 新增的软件包 (defconfig 后新增):"
        echo "----------------------------------------"
        if [ -f "$BEFORE_LIST" ] && [ -f "$AFTER_LIST" ]; then
            local new_packages
            new_packages=$(comm -13 "$BEFORE_LIST" "$AFTER_LIST")
            if [ -n "$new_packages" ]; then
                echo "$new_packages"
                echo ""
                echo "新增数量: $(echo "$new_packages" | wc -l)"
            else
                echo "无新增软件包"
            fi
        else
            echo "无法生成对比（文件不存在）"
        fi
        echo ""
        
        echo "🗑️  移除的软件包 (defconfig 后移除):"
        echo "----------------------------------------"
        if [ -f "$BEFORE_LIST" ] && [ -f "$AFTER_LIST" ]; then
            local removed_packages
            removed_packages=$(comm -23 "$BEFORE_LIST" "$AFTER_LIST")
            if [ -n "$removed_packages" ]; then
                echo "$removed_packages"
                echo ""
                echo "移除数量: $(echo "$removed_packages" | wc -l)"
            else
                echo "无移除软件包"
            fi
        else
            echo "无法生成对比（文件不存在）"
        fi
        echo ""
        
        echo "✅ 保持不变的软件包:"
        echo "----------------------------------------"
        if [ -f "$BEFORE_LIST" ] && [ -f "$AFTER_LIST" ]; then
            local unchanged_packages
            unchanged_packages=$(comm -12 "$BEFORE_LIST" "$AFTER_LIST")
            if [ -n "$unchanged_packages" ]; then
                echo "$unchanged_packages"
                echo ""
                echo "不变数量: $(echo "$unchanged_packages" | wc -l)"
            else
                echo "无保持不变的软件包"
            fi
        else
            echo "无法生成对比（文件不存在）"
        fi
        echo ""
        
        echo "⚠️  配置启用但不可用的软件包:"
        echo "----------------------------------------"
        if [ -f "$REPORT_DIR/enabled_luci_packages.txt" ] && [ -f "$AFTER_LIST" ]; then
            local missing_packages
            missing_packages=$(comm -23 "$REPORT_DIR/enabled_luci_packages.txt" "$AFTER_LIST")
            if [ -n "$missing_packages" ]; then
                echo "$missing_packages"
                echo ""
                echo "缺失数量: $(echo "$missing_packages" | wc -l)"
                echo "⚠️  这些软件包在配置中启用但不可用，请检查软件源是否正确添加"
            else
                echo "无缺失软件包"
            fi
        else
            echo "无法检查缺失软件包"
        fi
        echo ""
        
        echo "=================================================================="
    } > "$DIFF_REPORT"
    
    log_success "对比报告生成完成: $DIFF_REPORT"
}

# 显示报告摘要
show_report_summary() {
    log_step "报告摘要"
    
    if [ -f "$DIFF_REPORT" ]; then
        log_info "对比报告: $DIFF_REPORT"
        echo ""
        cat "$DIFF_REPORT"
    fi
    
    if [ -f "$DETAIL_REPORT" ]; then
        log_info "详细报告: $DETAIL_REPORT"
        echo ""
        # 只显示前20行
        head -20 "$DETAIL_REPORT"
        echo "..."
        echo "(完整报告请查看文件)"
    fi
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    show_execution_summary
    
    echo ""
    echo "报告文件:"
    echo "  - 对比报告: $DIFF_REPORT"
    echo "  - 详细报告: $DETAIL_REPORT"
    echo "  - defconfig 前列表: $BEFORE_LIST"
    echo "  - defconfig 后列表: $AFTER_LIST"
    echo "  - 启用软件包列表: $REPORT_DIR/enabled_luci_packages.txt"
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
        # 从配置文件提取启用的软件包
        extract_enabled_luci_packages
        
        # 获取 defconfig 前的软件包列表
        get_current_luci_packages "$BEFORE_LIST" "defconfig 前的 LUCI 软件包"
        
        # 执行 defconfig
        log_info "执行 make defconfig..."
        make defconfig
        
        # 获取 defconfig 后的软件包列表
        get_current_luci_packages "$AFTER_LIST" "defconfig 后的 LUCI 软件包"
        
        # 生成对比报告
        generate_diff_report
        
        # 生成详细报告
        generate_detailed_report
        
        # 显示报告摘要
        show_report_summary
        
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