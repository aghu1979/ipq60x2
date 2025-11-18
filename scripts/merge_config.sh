# scripts/merge_config.sh
# =============================================================================
# 配置文件合并脚本
# 版本: 1.0.1
# 更新日期: 2025-11-18
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取参数
BASE_CONFIG=$1
BRANCH_CONFIG=$2
VARIANT_CONFIG=$3
OUTPUT_CONFIG=$4
SELECTED_DEVICE=$5

echo -e "${BLUE}🔧 合并配置文件...${NC}"

# 检查参数
if [ $# -lt 4 ]; then
    echo -e "${RED}❌ 错误: 参数不足${NC}"
    echo -e "${YELLOW}用法: $0 <基础配置> <分支配置> <变体配置> <输出配置> [选定设备]${NC}"
    exit 1
fi

# 检查配置文件是否存在
for config in "$BASE_CONFIG" "$BRANCH_CONFIG" "$VARIANT_CONFIG"; do
    if [ ! -f "$config" ]; then
        echo -e "${RED}❌ 错误: 配置文件不存在: $config${NC}"
        exit 1
    fi
done

# 过滤掉注释行和空行，合并配置文件
grep -v '^#' "$BASE_CONFIG" | grep -v '^$' > temp_base.config
grep -v '^#' "$BRANCH_CONFIG" | grep -v '^$' > temp_branch.config
grep -v '^#' "$VARIANT_CONFIG" | grep -v '^$' > temp_variant.config

# 合并配置
cat temp_base.config temp_branch.config temp_variant.config > "$OUTPUT_CONFIG"

# 如果指定了设备，只保留指定设备的配置
if [ -n "$SELECTED_DEVICE" ]; then
    echo -e "${YELLOW}📱 只保留设备 $SELECTED_DEVICE 的配置${NC}"
    
    # 禁用所有设备
    sed -i 's/CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y/# CONFIG_TARGET_DEVICE_&/g' "$OUTPUT_CONFIG"
    
    # 启用指定设备
    sed -i "s/# CONFIG_TARGET_DEVICE_.*_DEVICE_${SELECTED_DEVICE}=y/CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_${SELECTED_DEVICE}=y/g" "$OUTPUT_CONFIG"
fi

# 清理临时文件
rm -f temp_base.config temp_branch.config temp_variant.config

echo -e "${GREEN}✅ 配置文件合并完成${NC}"
