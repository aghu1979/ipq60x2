#!/bin/bash
set -euo pipefail

# 此脚本合并三层配置文件：芯片、源码、变体。
# 用法: ./merge_configs.sh <repo_name> <variant_name>

REPO_NAME="$1"
VARIANT_NAME="$2"

CONFIGS_DIR="../configs"
FINAL_CONFIG_PATH=".config"

# 定义配置文件路径
BASE_CHIP_CONFIG="$CONFIGS_DIR/base_ipq60xx.config"
BASE_REPO_CONFIG="$CONFIGS_DIR/base_${REPO_NAME}.config"
VARIANT_CONFIG="$CONFIGS_DIR/${VARIANT_NAME}.config"

echo ">>> 开始合并配置文件..."

# 检查所有配置文件是否存在
for file in "$BASE_CHIP_CONFIG" "$BASE_REPO_CONFIG" "$VARIANT_CONFIG"; do
    if [ ! -f "$file" ]; then
        echo "错误: 配置文件 $file 不存在!" >&2
        exit 1
    fi
done

# 按顺序合并配置文件
echo "  - 合并 $BASE_CHIP_CONFIG"
cat "$BASE_CHIP_CONFIG" > "$FINAL_CONFIG_PATH"

echo "  - 合并 $BASE_REPO_CONFIG"
cat "$BASE_REPO_CONFIG" >> "$FINAL_CONFIG_PATH"

echo "  - 合并 $VARIANT_CONFIG"
cat "$VARIANT_CONFIG" >> "$FINAL_CONFIG_PATH"

echo "✅ 配置文件合并完成: $FINAL_CONFIG_PATH"
