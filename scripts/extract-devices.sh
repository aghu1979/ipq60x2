# scripts/extract-devices.sh
# =============================================================================
# 从配置文件中提取设备信息，去重后生成JSON格式输出
# 版本: 1.3.0
# 更新日期: 2025-11-19
# =============================================================================

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <配置文件路径>" >&2
    exit 1
fi

CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件 '$CONFIG_FILE' 不存在" >&2
    exit 1
fi

# 检查jq是否安装
if ! command -v jq &> /dev/null; then
    echo "错误: 'jq' 命令未找到，请先安装。" >&2
    exit 1
fi

echo ">>> 开始提取设备信息..." >&2

# 1. 从配置文件中提取设备名
# 2. 使用 sort -u 进行排序和去重
# 3. 使用 jq 将去重后的列表转换为紧凑的 JSON 数组字符串
devices_json=$(grep -E "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$CONFIG_FILE" \
    | sed -r 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_(.*)=y/\1/' \
    | sort -u \
    | jq -R . | jq -s -c .)

# 检查 jq 命令是否成功执行
if [ $? -ne 0 ]; then
    echo "错误: 'jq' 处理设备列表时失败。" >&2
    exit 1
fi

# 如果没有找到任何设备，jq会输出 "[]"
if [ "$devices_json" == "[]" ]; then
    echo "警告: 未在配置文件中找到任何设备。" >&2
fi

# 输出设备列表到标准错误，供用户在日志中查看
echo ">>> 提取到的设备列表:" >&2
echo "$devices_json" | jq -r '.[]' | sed 's/^/  - /' >&2

# 将紧凑的 JSON 数组写入文件，供后续步骤使用
echo "$devices_json" > devices.json

# --- 关键修改 ---
# 仅将最终的 JSON 字符串打印到标准输出
# 工作流将捕获此输出作为变量值
echo "$devices_json"
