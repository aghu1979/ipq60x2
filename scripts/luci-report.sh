# scripts/luci-report.sh
# =============================================================================
# 生成Luci软件包变更报告
# 版本: 1.4.0
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数
if [ $# -lt 3 ]; then
    echo "用法: $0 <ImmortalWrt源码目录> <变体名称> <输出文件路径> [DIY前配置文件路径]" >&2
    exit 1
fi

WORKDIR=$1
VARIANT=$2
OUTPUT_PATH=$3
PRE_Diy_CONFIG=$4 # 可选的第四个参数

cd "$WORKDIR" || exit 1

# 提取Luci软件包的函数
extract_luci_packages() {
    local config_file=$1
    grep "^CONFIG_PACKAGE_luci-.*=y" "$config_file" 2>/dev/null | sed 's/^CONFIG_PACKAGE_\(.*\)=y/\1/' | sort
}

# --- 核心逻辑变更 ---
# 如果提供了DIY前的配置文件，则使用它作为“原始”配置
if [ -n "$PRE_Diy_CONFIG" ] && [ -f "$PRE_Diy_CONFIG" ]; then
    echo ">>> 使用外部提供的基准配置文件: $PRE_Diy_CONFIG"
    original_packages=$(extract_luci_packages "$PRE_Diy_CONFIG")
else
    echo ">>> 未提供基准配置，将备份当前配置作为基准"
    # 备份defconfig前的配置
    cp .config .config.orig
    # 运行defconfig以补全依赖
    make defconfig > /dev/null 2>&1
    # 提取defconfig前的Luci软件包列表
    original_packages=$(extract_luci_packages .config.orig)
fi

# 提取最终的Luci软件包列表
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
    echo "  - DIY前Luci软件包数量: $original_count"
    echo "  - DIY后Luci软件包数量: $current_count"
    echo ""
    
    # --- 列出原始配置中的软件包 ---
    echo "🔵 DIY前Luci软件包列表:"
    echo "$original_packages" | sed 's/^/  - /'
    echo ""
    
    # --- 列出defconfig后的软件包 ---
    echo "🔵 DIY后Luci软件包列表:"
    echo "$current_packages" | sed 's/^/  - /'
    echo ""
    
    # --- 列出变更的软件包 ---
    echo "🟢 DIY新增的Luci软件包:"
    echo "$new_packages" | sed 's/^/  + /'
    echo ""
    
    echo "🔴 DIY移除的Luci软件包:"
    echo "$removed_packages" | sed 's/^/  - /'
    echo ""
    
    echo "🔵 DIY未变更的Luci软件包:"
    echo "$unchanged_packages" | sed 's/^/  - /'
} > "$OUTPUT_PATH"

# 在控制台也显示一份报告
cat "$OUTPUT_PATH"

# 输出状态标志，供工作流使用
echo "has_list=$has_list"
