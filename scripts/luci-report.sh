# scripts/luci-report.sh
# =============================================================================
# 生成Luci软件包变更报告
# 版本: 1.0.1
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "用法: $0 <ImmortalWrt源码目录> <变体名称>"
    exit 1
fi

WORKDIR=$1
VARIANT=$2
REPORT_FILE="$GITHUB_WORKSPACE/$LUCI_REPORT"

cd "$WORKDIR" || exit 1

# 备份defconfig前的配置
cp .config .config.orig

# 运行defconfig以补全依赖
make defconfig > /dev/null 2>&1

# 提取Luci软件包的函数
extract_luci_packages() {
    local config_file=$1
    grep "^CONFIG_PACKAGE_luci-.*=y" "$config_file" 2>/dev/null | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort
}

# 提取defconfig前后的Luci软件包列表
original_packages=$(extract_luci_packages .config.orig)
current_packages=$(extract_luci_packages .config)

# 生成报告
{
    echo "========================================"
    echo "Luci软件包变更报告 - $VARIANT 变体"
    echo "生成时间: $(date)"
    echo "========================================"
    echo ""
    
    # 统计软件包数量
    original_count=$(echo "$original_packages" | wc -l)
    current_count=$(echo "$current_packages" | wc -l)
    
    echo "📊 统计信息:"
    echo "  - 原始配置中的Luci软件包数量: $original_count"
    echo "  - defconfig后的Luci软件包数量: $current_count"
    echo ""
    
    # 使用comm命令比较两个已排序的列表
    # comm -12: 同时存在于两个文件中的行
    # comm -23: 只存在于第一个文件中的行
    # comm -13: 只存在于第二个文件中的行
    
    # 新增的软件包
    echo "🟢 新增的Luci软件包:"
    new_packages=$(comm -13 <(echo "$original_packages") <(echo "$current_packages"))
    if [ -n "$new_packages" ]; then
        echo "$new_packages" | sed 's/^/  + /'
    else
        echo "  无新增软件包"
    fi
    echo ""
    
    # 移除的软件包
    echo "🔴 移除的Luci软件包:"
    removed_packages=$(comm -23 <(echo "$original_packages") <(echo "$current_packages"))
    if [ -n "$removed_packages" ]; then
        echo "$removed_packages" | sed 's/^/  - /'
    else
        echo "  无移除软件包"
    fi
    echo ""
    
    # 未变更的软件包
    echo "🔵 未变更的Luci软件包:"
    unchanged_packages=$(comm -12 <(echo "$original_packages") <(echo "$current_packages"))
    if [ -n "$unchanged_packages" ]; then
        echo "$unchanged_packages" | wc -l | xargs -I {} echo "  共 {} 个软件包未变更"
    else
        echo "  无未变更软件包"
    fi
} > "$REPORT_FILE"

# 在控制台也显示一份报告
cat "$REPORT_FILE"
