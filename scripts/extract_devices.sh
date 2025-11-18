# scripts/extract_devices.sh
#!/bin/bash
# =============================================================================
# 设备名称提取和重命名脚本
# =============================================================================

# 检查参数
if [ $# -lt 1 ]; then
    echo "用法: $0 <配置文件路径>"
    exit 1
fi

CONFIG_FILE=$1

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 提取设备名称
echo "提取设备名称..."
DEVICES=$(grep -oE 'CONFIG_TARGET_DEVICE_[^_]+_DEVICE_[^=]+' "$CONFIG_FILE" | sed 's/CONFIG_TARGET_DEVICE_[^_]*_DEVICE_//')

if [ -z "$DEVICES" ]; then
    echo "警告: 未找到设备名称"
    exit 1
fi

echo "找到的设备:"
for device in $DEVICES; do
    echo "- $device"
done

# 生成重命名脚本
cat > rename_firmware.sh << EOF
#!/bin/bash
# =============================================================================
# 固件重命名脚本
# 自动生成，请勿手动修改
# =============================================================================

# 检查参数
if [ \$# -lt 2 ]; then
    echo "用法: \$0 <固件目录> <变体名称>"
    exit 1
fi

FIRMWARE_DIR=\$1
VARIANT=\$2
BUILD_DATE=\$(date +%Y-%m-%d)

# 检查目录是否存在
if [ ! -d "\$FIRMWARE_DIR" ]; then
    echo "错误: 固件目录不存在: \$FIRMWARE_DIR"
    exit 1
fi

# 重命名固件文件
echo "重命名固件文件..."
EOF

for device in $DEVICES; do
    echo "if [ -f \"\$FIRMWARE_DIR/immortalwrt-*-qualcommax-ipq60xx-${device}-squashfs-sysupgrade.bin\" ]; then" >> rename_firmware.sh
    echo "    mv \"\$FIRMWARE_DIR/immortalwrt-*-qualcommax-ipq60xx-${device}-squashfs-sysupgrade.bin\" \"\$FIRMWARE_DIR/ImmortalWrt-${device}-\${VARIANT}-\${BUILD_DATE}.bin\"" >> rename_firmware.sh
    echo "    echo \"重命名: ImmortalWrt-${device}-\${VARIANT}-\${BUILD_DATE}.bin\"" >> rename_firmware.sh
    echo "fi" >> rename_firmware.sh
done

echo "echo \"固件重命名完成\"" >> rename_firmware.sh
chmod +x rename_firmware.sh

echo "设备名称提取完成！"
echo "设备列表: $DEVICES"
echo "重命名脚本: rename_firmware.sh"
