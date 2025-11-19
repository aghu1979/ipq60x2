# scripts/extract-devices.sh
# =============================================================================
# 从配置文件中提取设备信息并生成JSON格式输出
# 版本: 1.0.0
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

# 使用jq来构建JSON，确保格式正确
echo "["

# 首次运行标志
first_entry=true

# 使用正则表达式匹配设备配置并循环处理
grep -E "^CONFIG_TARGET_DEVICE_.*_DEVICE_.*=y" "$CONFIG_FILE" | while read -r line; do
    # 提取设备名
    device_name=$(echo "$line" | sed -r 's/^CONFIG_TARGET_DEVICE_.*_DEVICE_(.*)=y/\1/')
    
    # 如果不是第一个条目，则添加逗号
    if [ "$first_entry" = false ]; then
        echo ","
    fi
    
    # 生成JSON格式的设备信息
    echo "  {"
    echo "    \"name\": \"$device_name\","
    echo "    \"config\": \"$line\""
    echo -n "  }"
    
    first_entry=false
done

echo "]"
