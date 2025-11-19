# scripts/merge-configs.sh
# =============================================================================
# 合并基础配置、分支配置和变体配置为一个完整的配置文件，并过滤注释
# 版本: 1.1.0
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数数量
if [ $# -ne 4 ]; then
    echo "用法: $0 <基础配置> <分支配置> <变体配置> <输出配置>" >&2
    exit 1
fi

BASE_CONFIG=$1
BRANCH_CONFIG=$2
VARIANT_CONFIG=$3
OUTPUT_CONFIG=$4

# 检查输入文件是否存在
for file in "$BASE_CONFIG" "$BRANCH_CONFIG" "$VARIANT_CONFIG"; do
    if [ ! -f "$file" ]; then
        echo "错误: 配置文件 '$file' 不存在" >&2
        exit 1
    fi
done

# 创建输出目录
mkdir -p "$(dirname "$OUTPUT_CONFIG")"

# 合并配置文件，并过滤掉源文件中的注释和空行
{
    echo "# 合并的配置文件 - 生成于 $(date)"
    echo "# 基础配置: $BASE_CONFIG"
    echo "# 分支配置: $BRANCH_CONFIG"
    echo "# 变体配置: $VARIANT_CONFIG"
    echo ""
    # 使用 sed 过滤掉以 # 开头的行和空行
    cat "$BASE_CONFIG" "$BRANCH_CONFIG" "$VARIANT_CONFIG" | sed '/^#/d; /^$/d'
} > "$OUTPUT_CONFIG"

echo "配置文件已成功合并到 '$OUTPUT_CONFIG' (已过滤注释和空行)"
