#!/bin/bash
# =============================================================================
# ImmortalWrt 固件自定义脚本
# 版本: 1.0.0
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

# 获取环境变量，如果未设置则使用默认值
FIRMWARE_IP=${FIRMWARE_IP:-"192.168.111.1"}
FIRMWARE_NAME=${FIRMWARE_NAME:-"WRT"}
AUTHOR_NAME=${AUTHOR_NAME:-"Mary"}

echo -e "${BLUE}🎨 开始应用自定义设置...${NC}"
echo -e "${CYAN}📅 版本: 1.0.0 (${AUTHOR_NAME})${NC}"
echo -e "${CYAN}📅 更新日期: 2025-11-18${NC}"

# 设置时区
export TZ=Asia/Shanghai
echo -e "${GREEN}✅ 时区设置为: Asia/Shanghai${NC}"

# 修改固件IP地址
if [ -f "package/base-files/files/bin/config_generate" ]; then
  sed -i "s/192.168.1.1/${FIRMWARE_IP}/g" package/base-files/files/bin/config_generate
  echo -e "${GREEN}✅ 固件IP地址修改为: ${FIRMWARE_IP}${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 config_generate 文件${NC}"
fi

# 修改机器名称
if [ -f "package/base-files/files/bin/config_generate" ]; then
  sed -i "s/OpenWrt/${FIRMWARE_NAME}/g" package/base-files/files/bin/config_generate
  echo -e "${GREEN}✅ 机器名称修改为: ${FIRMWARE_NAME}${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 config_generate 文件${NC}"
fi

# 修改作者信息
if [ -f "package/base-files/files/bin/config_generate" ]; then
  sed -i "s/OpenWrt/${AUTHOR_NAME}/g" package/base-files/files/bin/config_generate
  echo -e "${GREEN}✅ 作者信息修改为: ${AUTHOR_NAME}${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 config_generate 文件${NC}"
fi

# 设置默认密码为空
if [ -f "package/base-files/files/etc/shadow" ]; then
  sed -i 's/root::0:0:99999:7:::/root:$1$empty$6v/Dzg9SvF9m6S9L1H8V1.:18532:0:99999:7:::/' package/base-files/files/etc/shadow
  echo -e "${GREEN}✅ 默认密码设置为空${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 shadow 文件${NC}"
fi

# 修改默认主机名
if [ -d "package/base-files/files" ]; then
  echo "${FIRMWARE_NAME}" > package/base-files/files/etc/hostname
  echo -e "${GREEN}✅ 主机名设置为: ${FIRMWARE_NAME}${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 base-files/files 目录${NC}"
fi

# 添加自定义启动脚本
if [ -d "package/base-files/files" ]; then
  cat > package/base-files/files/etc/rc.local << EOF
#!/bin/sh
# 自定义启动脚本
# 版本: 1.0.0
# 更新日期: 2025-11-18

exit 0
EOF
  echo -e "${GREEN}✅ 添加自定义启动脚本${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 base-files/files 目录${NC}"
fi

echo -e "${GREEN}🎉 自定义设置应用完成！${NC}"
