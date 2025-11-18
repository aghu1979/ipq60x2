# scripts/extract_devices.sh
# =============================================================================
# 设备名称提取脚本
# 版本: 1.0.5
# 更新日期: 2025-11-18
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ 用法: $0 <配置文件路径>${NC}"
    exit 1
fi

CONFIG_FILE=$1

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 错误: 配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

# 提取设备名称
echo -e "${BLUE}📱 提取设备名称...${NC}"

# 使用正则表达式提取设备名称
# 匹配两种格式的设备配置：
# 1. CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_xxx=y
# 2. CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_xxx=y
# 使用更精确的正则表达式
devices=$(grep -E 'CONFIG_TARGET_.*qualcommax_ipq60xx_DEVICE_[^=]+=y' "$CONFIG_FILE" | sed -E 's/CONFIG_TARGET_.*qualcommax_ipq60xx_DEVICE_([^=]+)=y/\1/' | sort -u)

if [ -z "$devices" ]; then
    echo -e "${YELLOW}⚠️ 警告: 未找到设备名称，使用默认设备${NC}"
    devices="jdcloud_re-ss-01 jdcloud_re-cs-02 jdcloud_rz-caa-07"
fi

echo -e "${GREEN}✅ 找到的设备:${NC}"
for device in $devices; do
    echo -e "  📱 $device"
done

# 生成重命名脚本
cat > rename_firmware.sh << EOF
#!/bin/bash
# =============================================================================
# 固件重命名脚本
# 版本: 1.0.5
# 更新日期: 2025-11-18
# 自动生成，请勿手动修改
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ \$# -lt 2 ]; then
    echo -e "\${RED}❌ 用法: \$0 <固件目录> <变体名称>\${NC}"
    exit 1
fi

FIRMWARE_DIR=\$1
VARIANT=\$2
BUILD_DATE=\$(date +%Y-%m-%d)

# 检查目录是否存在
if [ ! -d "\$FIRMWARE_DIR" ]; then
    echo -e "\${RED}❌ 错误: 固件目录不存在: \$FIRMWARE_DIR\${NC}"
    exit 1
fi

# 设备列表
DEVICES="$devices"

# 重命名固件文件
echo -e "\${BLUE}🔄 重命名固件文件...\${NC}"
for device in \$DEVICES; do
    if [ -f "\$FIRMWARE_DIR/immortalwrt-*-qualcommax-ipq60xx-\$device-squashfs-sysupgrade.bin" ]; then
        mv "\$FIRMWARE_DIR/immortalwrt-*-qualcommax-ipq60xx-\$device-squashfs-sysupgrade.bin" "\$FIRMWARE_DIR/ImmortalWrt-\$device-\${VARIANT}-\${BUILD_DATE}.bin"
        echo -e "\${GREEN}✅ 重命名: ImmortalWrt-\$device-\${VARIANT}-\${BUILD_DATE}.bin\${NC}"
    else
        echo -e "\${YELLOW}⚠️ 警告: 找不到设备 \$device 的固件文件\${NC}"
    fi
done

echo -e "\${GREEN}🎉 固件重命名完成\${NC}"
EOF

chmod +x rename_firmware.sh

echo -e "${GREEN}✅ 设备名称提取完成！${NC}"
echo -e "${CYAN}📱 设备列表: $devices${NC}"
echo -e "${CYAN}📄 重命名脚本: rename_firmware.sh${NC}"

# 输出设备列表（不包含颜色代码，供其他脚本使用）
echo "$devices"
