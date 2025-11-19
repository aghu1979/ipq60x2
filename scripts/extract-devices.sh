# scripts/extract-devices.sh
# =============================================================================
# 从配置文件中提取设备信息，去重后生成JSON格式输出
# 版本: 1.1.0
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <配置文件路径>"
    exit 1
fi

CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件 '$CONFIG_FILE' 不存在"
    exit 1
fi

# 检查jq是否安装
if ! command -v jq &> /dev/null; then
    echo "错误: 'jq' 命令未找到，请先安装。"
    exit 1
fi

echo ">>> 开始提取设备信息..."

# 1. 从配置文件中提取设备名
# 2. 使用 sort -u 进行排序和去重
# 3. 使用 jq 将去重后的列表转换为 JSON 数组
devices_json=$(grep -E "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$CONFIG_FILE" \
    | sed -r 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_(.*)=y/\1/' \
    | sort -u \
    | jq -R . | jq -s .)

if [ -z "$devices_json" ] || [ "$devices_json" == "[]" ]; then
    echo "警告: 未在配置文件中找到任何设备。"
    devices_json="[]"
fi

# 输出 JSON 到控制台，以便调试
echo ">>> 提取到的设备信息:"
echo "$devices_json" | jq -C .

# 将 JSON 数组写入文件，供后续步骤使用
echo "$devices_json" > devices.json

# 设置 GitHub Actions 输出，确保是单行且格式正确
# 注意：GITHUB_OUTPUT 文件在较新的 Actions 版本中是标准方式
echo "devices=$devices_json" >> $GITHUB_OUTPUT

echo ">>> 设备信息提取完成，并已保存至 devices.json"
