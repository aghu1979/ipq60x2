#!/bin/bash
# =============================================================================
# LUCI 软件包变更报告生成脚本
# 版本: 1.0
# 描述: 生成Luci软件包差异报告
# =============================================================================

# 加载通用函数库
source "$(dirname "$0")/common.sh"

# 全局变量
REPO_PATH="${REPO_PATH:-$(pwd)}"
CONFIG_FILE="${CONFIG_FILE:-configs/immu.config}"
REPORT_FILE="$REPO_PATH/luci_report_$(date +%Y%m%d_%H%M%S).txt"

log_work "开始生成Luci软件包差异报告..."

# 提取配置中的Luci包
extract_luci_packages_from_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "从配置文件提取Luci软件包..."
    
    # 提取不以#开头且以=y结尾的luci包
    local luci_packages=$(grep "^CONFIG_PACKAGE_luci-.*=y" "$config_file" | \
        sed 's/^CONFIG_PACKAGE_//g' | \
        sed 's/=y$//g' | \
        sort)
    
    echo "$luci_packages"
}

# 获取已安装的Luci包
get_installed_luci_packages() {
    log_info "获取已安装的Luci软件包..."
    
    # 从Makefile中查找luci包
    local installed_packages=$(find "$REPO_PATH" -name "Makefile" -exec grep -l "Package/luci-" {} \; | \
        xargs grep -h "Package/luci-" | \
        awk '{print $2}' | \
        sed 's/Package\///g' | \
        sort -u)
    
    echo "$installed_packages"
}

# 生成差异报告
generate_diff_report() {
    local config_packages=$1
    local installed_packages=$2
    
    log_info "生成差异报告..."
    
    # 创建临时文件
    local config_temp=$(mktemp)
    local installed_temp=$(mktemp)
    
    echo "$config_packages" > "$config_temp"
    echo "$installed_packages" > "$installed_temp"
    
    # 生成报告
    {
        echo "=================================================================="
        echo "LUCI 软件包差异报告"
        echo "=================================================================="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "配置文件: $CONFIG_FILE"
        echo "源码路径: $REPO_PATH"
        echo ""
        
        echo "【配置文件中的Luci包】"
        echo "总数: $(wc -l < "$config_temp")"
        echo "----------------------------------------"
        cat "$config_temp"
        echo ""
        
        echo "【系统中可用的Luci包】"
        echo "总数: $(wc -l < "$installed_temp")"
        echo "----------------------------------------"
        cat "$installed_temp"
        echo ""
        
        echo "【新增包】(配置中有，系统中没有)"
        echo "----------------------------------------"
        comm -23 "$config_temp" "$installed_temp" || echo "无"
        echo ""
        
        echo "【移除包】(系统中有，配置中没有) - 注意：这可能是默认包"
        echo "----------------------------------------"
        comm -13 "$config_temp" "$installed_temp" || echo "无"
        echo ""
        
        echo "【共同包】"
        echo "----------------------------------------"
        comm -12 "$config_temp" "$installed_temp" || echo "无"
        echo ""
        
        echo "=================================================================="
        echo "统计信息"
        echo "=================================================================="
        echo "配置包数量: $(wc -l < "$config_temp")"
        echo "可用包数量: $(wc -l < "$installed_temp")"
        echo "新增包数量: $(comm -23 "$config_temp" "$installed_temp" | wc -l)"
        echo "移除包数量: $(comm -13 "$config_temp" "$installed_temp" | wc -l)"
        echo "共同包数量: $(comm -12 "$config_temp" "$installed_temp" | wc -l)"
        echo ""
        
        echo "=================================================================="
        echo "包分类统计"
        echo "=================================================================="
        
        # 按类别统计
        echo "【应用类】"
        grep "^luci-app-" "$config_temp" 2>/dev/null || echo "无"
        echo ""
        
        echo "【主题类】"
        grep "^luci-theme-" "$config_temp" 2>/dev/null || echo "无"
        echo ""
        
        echo "【协议类】"
        grep "^luci-proto-" "$config_temp" 2>/dev/null || echo "无"
        echo ""
        
        echo "【国际化】"
        grep "^luci-i18n-" "$config_temp" 2>/dev/null || echo "无"
        echo ""
        
        echo "【其他】"
        grep -v "^luci-\(app\|theme\|proto\|i18n\)-" "$config_temp" 2>/dev/null || echo "无"
        echo ""
        
        echo "=================================================================="
        echo "报告生成完成"
        echo "=================================================================="
        
    } > "$REPORT_FILE"
    
    # 清理临时文件
    rm -f "$config_temp" "$installed_temp"
    
    log_success "报告已生成: $REPORT_FILE"
}

# 显示报告摘要
show_report_summary() {
    if [ ! -f "$REPORT_FILE" ]; then
        log_error "报告文件不存在"
        return 1
    fi
    
    log_info "报告摘要:"
    echo "----------------------------------------"
    
    # 提取关键信息
    grep -E "(配置包数量|可用包数量|新增包数量|移除包数量|共同包数量)" "$REPORT_FILE" | while read line; do
        echo "  $line"
    done
    
    echo "----------------------------------------"
    echo "完整报告路径: $REPORT_FILE"
}

# 验证报告
validate_report() {
    if [ ! -f "$REPORT_FILE" ]; then
        log_error "报告文件生成失败"
        return 1
    fi
    
    if [ ! -s "$REPORT_FILE" ]; then
        log_error "报告文件为空"
        return 1
    fi
    
    log_success "报告验证通过"
    return 0
}

# 主函数
main() {
    log_work "开始Luci报告生成流程..."
    
    # 提取包列表
    local config_packages=$(extract_luci_packages_from_config "$CONFIG_FILE")
    local installed_packages=$(get_installed_luci_packages)
    
    # 生成报告
    generate_diff_report "$config_packages" "$installed_packages"
    
    # 验证报告
    if validate_report; then
        show_report_summary
        log_success "Luci软件包差异报告生成完成！"
    else
        log_error "报告生成失败"
        exit 1
    fi
}

# 执行主函数
main "$@"
