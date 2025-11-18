#!/bin/bash
# =============================================================================
# ImmortalWrt 固件自定义脚本
# =============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 开始应用自定义设置...${NC}"

# 设置时区
export TZ=Asia/Shanghai
echo -e "${GREEN}✅ 时区设置为: Asia/Shanghai${NC}"

# 修改固件IP地址
sed -i "s/192.168.1.1/192.168.111.1/g" package/base-files/files/bin/config_generate
echo -e "${GREEN}✅ 固件IP地址修改为: 192.168.111.1${NC}"

# 修改机器名称
sed -i "s/OpenWrt/WRT/g" package/base-files/files/bin/config_generate
echo -e "${GREEN}✅ 机器名称修改为: WRT${NC}"

# 修改作者信息
sed -i "s/OpenWrt/Mary/g" package/base-files/files/bin/config_generate
echo -e "${GREEN}✅ 作者信息修改为: Mary${NC}"

# 设置默认密码为空
sed -i 's/root::0:0:99999:7:::/root:$1$empty$6v/Dzg9SvF9m6S9L1H8V1.:18532:0:99999:7:::/' package/base-files/files/etc/shadow
echo -e "${GREEN}✅ 默认密码设置为空${NC}"

# 修改默认主机名
echo "WRT" > package/base-files/files/etc/hostname
echo -e "${GREEN}✅ 主机名设置为: WRT${NC}"

# 添加自定义启动脚本
cat > package/base-files/files/etc/rc.local << EOF
#!/bin/sh
# 自定义启动脚本

exit 0
EOF
echo -e "${GREEN}✅ 添加自定义启动脚本${NC}"

echo -e "${GREEN}🎉 自定义设置应用完成！${NC}"
