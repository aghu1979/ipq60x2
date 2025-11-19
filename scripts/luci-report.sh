# scripts/luci-report.sh
# =============================================================================
# 生成Luci软件包变更报告
# 版本: 1.4.0
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "用法: $0 <ImmortalWrt源码目录> <变体名称> <输出文件路径> [原始列表文件]" >&2
    exit 1
fi

WORKDIR=$1
VARIANT=$2
OUTPUT_PATH=$3
ORIGINAL_LIST_FILE=$4 # 新增第四个可选参数

cd "$WORKDIR" || exit 1

# 提取Luci软件包的函数
extract_luci_packages() {
    local config_file=$1
    grep "^CONFIG_PACKAGE_luci-.*=y" "$config_file" 2>/dev/null | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort
}

# --- 决定原始列表的来源 ---
if [ -n "$ORIGINAL_LIST_FILE" ] && [ -f "$ORIGINAL_LIST_FILE" ]; then
    # 如果提供了原始列表文件，则直接读取
    echo ">>> 从文件加载原始Luci列表: $ORIGINAL_LIST_FILE"
    original_packages=$(cat "$ORIGINAL_LIST_FILE")
else
    # 否则，备份当前配置并从中提取
    echo ">>> 备份当前配置并提取原始Luci列表..."
    cp .config .config.orig
    original_packages=$(extract_luci_packages .config.orig)
fi

# --- 获取最终列表 ---
echo ">>> 运行 make defconfig 并提取最终Luci列表..."
make defconfig > /dev/null 2>&1
current_packages=$(extract_luci_packages .config)

# 使用comm命令比较两个已排序的列表
new_packages=$(comm -13 <(echo "$original_packages") <(echo "$current_packages"))
removed_packages=$(comm -23 <(echo "$original_packages") <(echo "$current_packages"))
unchanged_packages=$(comm -12 <(echo "$original_packages") <(echo "$current_packages"))

# 判断报告中是否包含任何软件包列表
has_list=false
if [[ "$new_packages" =~ [^[:space:]] ]] || [[ "$removed_packages" =~ [^[:space:]] ]] || [[ "$unchanged_packages" =~ [^[:space:]] ]]; then
    has_list=true
fi

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
    echo "  - 最终配置中的Luci软件包数量: $current_count"
    echo ""
    
    # --- 列出变更的软件包 ---
    echo "🟢 新增的Luci软件包:"
    echo "$new_packages" | sed 's/^/  + /'
    echo ""
    
    echo "🔴 移除的Luci软件包:"
    echo "$removed_packages" | sed 's/^/  - /'
    echo ""
    
    echo "🔵 未变更的Luci软件包:"
    echo "$unchanged_packages" | sed 's/^/  - /'
} > "$OUTPUT_PATH"

# 在控制台也显示一份报告
cat "$OUTPUT_PATH"

# 输出状态标志，供工作流使用
echo "has_list=$has_list"
