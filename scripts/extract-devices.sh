# scripts/extract-devices.sh
# =============================================================================
# 从配置文件中提取设备信息，去重后生成JSON格式输出
# 版本: 1.2.0
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
# 3. 使用 jq 将去重后的列表转换为紧凑的 JSON 数组字符串
#    -R . 将每行作为原始字符串处理
#    -s   将所有行读入一个数组
#    -c   生成紧凑的单行输出，这是 GITHUB_OUTPUT 的要求
devices_json=$(grep -E "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$CONFIG_FILE" \
    | sed -r 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_(.*)=y/\1/' \
    | sort -u \
    | jq -R . | jq -s -c .)

# 检查 jq 命令是否成功执行
if [ $? -ne 0 ]; then
    echo "错误: 'jq' 处理设备列表时失败。"
    exit 1
fi

# 如果没有找到任何设备，jq会输出 "[]"
if [ "$devices_json" == "[]" ]; then
    echo "警告: 未在配置文件中找到任何设备。"
fi

# 输出设备列表到控制台，便于查看
echo ">>> 提取到的设备列表:"
echo "$devices_json" | jq -r '.[]' | sed 's/^/  - /'

# 将紧凑的 JSON 数组写入文件，供后续步骤使用
echo "$devices_json" > devices.json

# 设置 GitHub Actions 输出，确保 value 是一个单行字符串
echo "devices=$devices_json" >> $GITHUB_OUTPUT

echo ">>> 设备信息提取完成，并已保存至 devices.json"
