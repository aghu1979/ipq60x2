# scripts/repo.sh
# =============================================================================
# ImmortalWrt 第三方软件源添加脚本
# 版本: 1.0.7
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

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/repo_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}🚀 开始添加第三方软件源...${NC}"
echo -e "${CYAN}📅 版本: 1.0.7${NC}"
echo -e "${CYAN}📅 更新日期: 2025-11-18${NC}"
echo -e "${CYAN}📅 时间: $(date)${NC}"

# 保存添加前的luci软件包列表
echo -e "${BLUE}📋 保存添加前的LUCI软件包列表...${NC}"
if [ -f ".config" ]; then
  grep -E '^CONFIG_PACKAGE_luci.*=y$' .config > luci-before.txt || true
  before_count=$(wc -l < luci-before.txt 2>/dev/null || echo 0)
  echo -e "${CYAN}📦 添加前LUCI软件包数量: $before_count${NC}"
else
  touch luci-before.txt
  before_count=0
fi

# 检查网络连接
echo -e "${BLUE}🔍 检查网络连接...${NC}"
if ! ping -c 1 github.com &> /dev/null; then
    echo -e "${RED}❌ 错误: 无法连接到GitHub，但继续执行脚本${NC}"
else
    echo -e "${GREEN}✅ 网络连接正常${NC}"
fi

# 创建备份目录
mkdir -p backup
if [ -f "feeds.conf.default" ]; then
  cp feeds.conf.default backup/feeds.conf.default.bak
  echo -e "${GREEN}✅ 备份原始 feeds.conf.default${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 添加Passwall软件源
if [ -f "feeds.conf.default" ]; then
  echo -e "${YELLOW}📦 添加Passwall软件源...${NC}"
  sed -i '1i\src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main\nsrc-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 添加Passwall2软件源
if [ -f "feeds.conf.default" ]; then
  echo -e "${YELLOW}📦 添加Passwall2软件源...${NC}"
  echo "src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main" >> feeds.conf.default
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 添加Momo和Nikki软件源
if [ -f "feeds.conf.default" ]; then
  echo -e "${YELLOW}📦 添加Momo和Nikki软件源...${NC}"
  echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo;main" >> feeds.conf.default
  echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki;main" >> feeds.conf.default
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 添加OpenClash软件源
if [ -f "feeds.conf.default" ]; then
  echo -e "${YELLOW}📦 添加OpenClash软件源...${NC}"
  echo "src-git openclash https://github.com/vernesong/OpenClash.git" >> feeds.conf.default
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 添加主题源
echo -e "${YELLOW}🎨 添加主题源...${NC}"
mkdir -p feeds/luci/themes
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon 2>/dev/null || echo -e "${RED}⚠️ 警告: 无法克隆Argon主题${NC}"
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora 2>/dev/null || echo -e "${RED}⚠️ 警告: 无法克隆Aurora主题${NC}"

# 克隆第三方软件包
echo -e "${BLUE}📥 开始克隆第三方软件包...${NC}"

# 定义克隆函数
clone_package() {
    local name=$1
    local url=$2
    local path=$3
    
    echo -e "${CYAN}🔄 克隆 $name...${NC}"
    if git clone $url $path 2>/dev/null; then
        echo -e "${GREEN}✅ $name 克隆成功${NC}"
        # 设置权限（如果有脚本）
        if [ -f "$path/root/etc/init.d/athena_led" ]; then
            chmod +x $path/root/etc/init.d/athena_led $path/root/usr/sbin/athena-led 2>/dev/null
        fi
    else
        echo -e "${RED}❌ $name 克隆失败${NC}"
    fi
}

# 京东云雅典娜LED控制
clone_package "京东云雅典娜LED控制" "https://github.com/NONGFAH/luci-app-athena-led" "package/luci-app-athena-led"

# AdGuardHome
clone_package "AdGuardHome" "https://github.com/sirpdboy/luci-app-adguardhome" "package/luci-app-adguardhome"

# ddns-go
clone_package "ddns-go" "https://github.com/sirpdboy/luci-app-ddns-go" "package/luci-app-ddns-go"

# luci-app-netdata
clone_package "luci-app-netdata" "https://github.com/sirpdboy/luci-app-netdata" "package/luci-app-netdata"

# luci-app-netspeedtest
clone_package "luci-app-netspeedtest" "https://github.com/sirpdboy/luci-app-netspeedtest" "package/luci-app-netspeedtest"

# luci-app-partexp
clone_package "luci-app-partexp" "https://github.com/sirpdboy/luci-app-partexp" "package/luci-app-partexp"

# luci-app-taskplan
clone_package "luci-app-taskplan" "https://github.com/sirpdboy/luci-app-taskplan" "package/luci-app-taskplan"

# lucky
clone_package "lucky" "https://github.com/gdy666/luci-app-lucky" "package/lucky"

# luci-app-easytier
clone_package "luci-app-easytier" "https://github.com/EasyTier/luci-app-easytier" "package/luci-app-easytier"

# homeproxy
clone_package "homeproxy" "https://github.com/VIKINGYFY/homeproxy" "package/homeproxy"

# golang & luci-app-openlist2
clone_package "golang" "https://github.com/sbwml/packages_lang_golang -b 25.x" "feeds/packages/lang/golang"
clone_package "luci-app-openlist2" "https://github.com/sbwml/luci-app-openlist2" "package/luci-app-openlist"

# luci-app-mosdns
clone_package "luci-app-mosdns" "https://github.com/sbwml/luci-app-mosdns -b v5" "package/luci-app-mosdns"

# luci-app-quickfile
clone_package "luci-app-quickfile" "https://github.com/sbwml/luci-app-quickfile" "package/luci-app-quickfile"

# OpenAppFilter（OAF）
clone_package "OpenAppFilter" "https://github.com/destan19/OpenAppFilter" "package/luci-app-oaf"

# tailscale
echo -e "${CYAN}🔄 处理tailscale...${NC}"
if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
  sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile 2>/dev/null || echo -e "${RED}⚠️ 警告: 无法修改tailscale Makefile${NC}"
else
  echo -e "${YELLOW}⚠️ 警告: 找不到 tailscale Makefile${NC}"
fi
clone_package "luci-app-tailscale" "https://github.com/asvow/luci-app-tailscale" "package/luci-app-tailscale"

# vnt
clone_package "vnt" "https://github.com/lmq8267/luci-app-vnt" "package/luci-app-vnt"

# kenzok8/small-package（备用）
clone_package "kenzok8/small-package（备用）" "https://github.com/kenzok8/small-package" "small"

# 显示已添加的软件源
if [ -f "feeds.conf.default" ]; then
  echo -e "\n${PURPLE}📋 已添加的软件源:${NC}"
  cat feeds.conf.default | grep -v "^#" | grep -v "^$" | while read line; do
      echo -e "  🔗 $line"
  done
else
  echo -e "\n${YELLOW}⚠️ 警告: 找不到 feeds.conf.default 文件${NC}"
fi

# 显示已克隆的软件包
if [ -d "package" ]; then
  echo -e "\n${PURPLE}📦 已克隆的软件包:${NC}"
  ls -la package/ | grep "^d" | grep -v "base\|freifunk\|kernel\|libs\|network\|system\|utils\|mail\|multimedia\|sound\|languages" | awk '{print "  📁 " $9}'
else
  echo -e "\n${YELLOW}⚠️ 警告: 找不到 package 目录${NC}"
fi

# 生成添加后的LUCI软件包报告
echo -e "\n${BLUE}📋 生成添加后的LUCI软件包报告...${NC}"
if [ -f ".config" ]; then
  grep -E '^CONFIG_PACKAGE_luci.*=y$' .config > luci-after.txt || true
  after_count=$(wc -l < luci-after.txt 2>/dev/null || echo 0)
  
  echo -e "\n${CYAN}📦 添加第三方软件源后的LUCI软件包 ($after_count个):${NC}"
  if [ -f "luci-after.txt" ]; then
    cat luci-after.txt | while read line; do
      pkg=$(echo $line | sed 's/CONFIG_PACKAGE_//g' | sed 's/=y//g')
      echo -e "  ✨ $pkg"
    done
  fi
  
  # 生成对比报告
  if [ -f "luci-before.txt" ] && [ -f "luci-after.txt" ]; then
    echo -e "\n${GREEN}➕ 新增的LUCI软件包:${NC}"
    comm -13 luci-before.txt luci-after.txt | while read line; do
      pkg=$(echo $line | sed 's/CONFIG_PACKAGE_//g' | sed 's/=y//g')
      echo -e "  ✨ $pkg"
    done || echo -e "  📭 无新增"
    
    echo -e "\n${RED}➖ 移除的LUCI软件包:${NC}"
    comm -23 luci-before.txt luci-after.txt | while read line; do
      pkg=$(echo $line | sed 's/CONFIG_PACKAGE_//g' | sed 's/=y//g')
      echo -e "  🗑️ $pkg"
    done || echo -e "  📭 无移除"
    
    # 生成摘要
    added_count=$(comm -13 luci-before.txt luci-after.txt | wc -l)
    removed_count=$(comm -23 luci-before.txt luci-after.txt | wc -l)
    echo -e "\n${PURPLE}📊 摘要: 添加前($before_count个) -> 添加后($after_count个), 新增$added_count个, 移除$removed_count个${NC}"
  fi
else
  echo -e "\n${YELLOW}⚠️ 警告: 找不到 .config 文件${NC}"
fi

echo -e "\n${GREEN}🎉 第三方软件源添加完成！${NC}"
echo -e "${CYAN}📄 日志文件: $LOG_FILE${NC}"
