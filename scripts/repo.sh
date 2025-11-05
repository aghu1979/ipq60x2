#!/bin/bash

# ==============================================================================
# OpenWrt 第三方软件源集成脚本
#
# 功能:
#   添加和管理OpenWrt/ImmortalWrt的第三方软件源
#   包括各种常用插件和工具的集成
#
# 使用方法:
#   ./repo.sh
#
# 作者: Mary
# 日期：20251104
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 包目录
PACKAGE_DIR="package"
# 小型包仓库目录
SMALL_PACKAGE_DIR="small"
# Feeds配置文件
FEEDS_CONF="feeds.conf.default"
# 配置文件路径
CONFIG_FILE="${CONFIG_FILE:-.config}"

# --- 需要检查删除的官方Feeds软件包名称列表 ---
# 这些软件包可能与第三方源冲突，需要检查并删除官方版本
PKG_LIST=(
    "lucky"
    "luci-app-lucky"
    "homeproxy"
    "luci-app-homeproxy"
    "nikki"
    "luci-app-nikki"
    "momo"
    "luci-app-momo"
    "adguardhome"
    "luci-app-adguardhome"
    "ddns-go"
    "luci-app-ddns-go"
    "netdata"
    "luci-app-netdata"
    "netspeedtest"
    "luci-app-netspeedtest"
    "partexp"
    "luci-app-partexp"
    "taskplan"
    "luci-app-taskplan"
    "easytier"
    "luci-app-easytier"
    "openlist2"
    "luci-app-openlist2"
    "mosdns"
    "luci-app-mosdns"
    "quickfile"
    "luci-app-quickfile"
    "OpenAppFilter"
    "luci-app-oaf"
    "openclash"
    "luci-app-openclash"
    "tailscale"
    "luci-app-tailscale"
    "vnt"
    "luci-app-vnt"
    "athena-led"
    "luci-app-athena-led"
    "passwall"
    "luci-app-passwall"
    "passwall2"
    "luci-app-passwall2"
    "istorex"
    "luci-app-istorex"
    "quickstart"
    "luci-app-quickstart"
    "wolplus"
    "luci-app-wolplus"
    "diskman"
    "luci-app-diskman"
    "vlmcsd"
    "luci-app-vlmcsd"
)

# --- PassWall 相关依赖包列表 ---
# 这些是 PassWall 的依赖包，需要删除官方版本
PASSWALL_DEPS=(
    "xray-core"
    "v2ray-geodata"
    "sing-box"
    "chinadns-ng"
    "dns2socks"
    "hysteria"
    "ipt2socks"
    "microsocks"
    "naiveproxy"
    "shadowsocks-libev"
    "shadowsocks-rust"
    "shadowsocksr-libev"
    "simple-obfs"
    "tcping"
    "trojan-plus"
    "tuic-client"
    "v2ray-plugin"
    "xray-plugin"
    "geoview"
    "shadow-tls"
)

# --- 第三方软件源映射 ---
# 定义每个包的首选源和后备源
declare -A PACKAGE_SOURCES=(
    # 主要软件源
    ["luci-app-athena-led"]="https://github.com/NONGFAH/luci-app-athena-led.git"
    ["passwall-packages"]="https://github.com/xiaorouji/openwrt-passwall-packages.git"
    ["passwall-luci"]="https://github.com/xiaorouji/openwrt-passwall.git"
    ["passwall2-luci"]="https://github.com/xiaorouji/openwrt-passwall2.git"
    ["luci-app-adguardhome"]="https://github.com/sirpdboy/luci-app-adguardhome.git"
    ["ddns-go"]="https://github.com/sirpdboy/luci-app-ddns-go.git"
    ["luci-app-netdata"]="https://github.com/sirpdboy/luci-app-netdata.git"
    ["luci-app-netspeedtest"]="https://github.com/sirpdboy/luci-app-netspeedtest.git"
    ["luci-app-partexp"]="https://github.com/sirpdboy/luci-app-partexp.git"
    ["luci-app-taskplan"]="https://github.com/sirpdboy/luci-app-taskplan.git"
    ["lucky"]="https://github.com/gdy666/luci-app-lucky.git"
    ["luci-app-easytier"]="https://github.com/EasyTier/luci-app-easytier.git"
    ["homeproxy"]="https://github.com/VIKINGYFY/homeproxy.git"
    ["openlist"]="https://github.com/sbwml/luci-app-openlist2.git"
    ["mosdns"]="https://github.com/sbwml/luci-app-mosdns.git"
    ["quickfile"]="https://github.com/sbwml/luci-app-quickfile.git"
    ["luci-app-momo"]="https://github.com/nikkinikki-org/OpenWrt-momo.git"
    ["luci-app-nikki"]="https://github.com/nikkinikki-org/OpenWrt-nikki.git"
    ["OpenAppFilter"]="https://github.com/destan19/OpenAppFilter.git"
    ["luci-app-openclash"]="https://github.com/vernesong/OpenClash.git"
    ["luci-app-tailscale"]="https://github.com/asvow/luci-app-tailscale.git"
    ["luci-app-vnt"]="https://github.com/lmq8267/luci-app-vnt.git"
    
    # 特殊处理的包
    ["golang"]="https://github.com/sbwml/packages_lang_golang.git"
)

# --- small-package 包映射 ---
# small-package 中的包可能有不同的命名规则
declare -A SMALL_PACKAGE_MAPPING=(
    ["luci-app-istorex"]="luci-app-istorex"
    ["luci-app-quickstart"]="luci-app-quickstart"
    ["luci-app-wolplus"]="luci-app-wolplus"
    ["luci-app-diskman"]="luci-app-diskman"
    ["luci-app-vlmcsd"]="luci-app-vlmcsd"
    # 可能的别名
    ["quickstart"]="luci-app-quickstart"
    ["vlmcsd"]="luci-app-vlmcsd"
)

# --- 可能需要从 small-package 后备的包 ---
# 这些包如果主要源失败，将从 small-package 获取
SMALL_PACKAGE_BACKUP_LIST=(
    "luci-app-istorex"
    "luci-app-quickstart"
    "luci-app-wolplus"
    "luci-app-diskman"
    "luci-app-vlmcsd"
)

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

# 初始化统计变量
TOTAL_PACKAGES=0
SUCCESS_PACKAGES=0
FAILED_PACKAGES=0
FAILED_PACKAGE_LIST=""
BACKUP_USED_PACKAGES=""

log_step "开始执行 OpenWrt 第三方软件源集成"

# 检查是否在OpenWrt根目录
if [ ! -f "Makefile" ] || [ ! -d "scripts" ]; then
    log_error "当前目录不是OpenWrt根目录，请在OpenWrt根目录下运行此脚本"
    exit 1
fi

# 创建必要的目录
safe_mkdir "$PACKAGE_DIR"
safe_mkdir "$SMALL_PACKAGE_DIR"

# --- 预处理：删除可能冲突的官方软件包 ---
log_step "预处理：删除可能冲突的官方软件包"

# 删除本地可能存在的不同名称的软件包
for NAME in "${PKG_LIST[@]}"; do
    # 查找匹配的目录
    log_info "搜索目录: $NAME"
    FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

    # 删除找到的目录
    if [ -n "$FOUND_DIRS" ]; then
        while read -r DIR; do
            log_info "删除目录: $DIR"
            rm -rf "$DIR"
        done <<< "$FOUND_DIRS"
    else
        log_debug "未找到目录: $NAME"
    fi
done

log_success "预处理完成，已删除可能冲突的官方软件包"

# --- 添加第三方软件源 ---

# 1. 处理 PassWall 依赖
log_info "处理 PassWall 相关依赖"
for NAME in "${PASSWALL_DEPS[@]}"; do
    log_debug "搜索 PassWall 依赖目录: $NAME"
    FOUND_DIRS=$(find ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
    if [ -n "$FOUND_DIRS" ]; then
        while read -r DIR; do
            log_debug "删除 PassWall 依赖目录: $DIR"
            rm -rf "$DIR"
        done <<< "$FOUND_DIRS"
    fi
done

# 2. 添加主要软件源
log_step "添加主要第三方软件源"
for PKG_NAME in "${!PACKAGE_SOURCES[@]}"; do
    TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
    PKG_URL="${PACKAGE_SOURCES[$PKG_NAME]}"
    TARGET_DIR="$PACKAGE_DIR/$PKG_NAME"
    
    # 特殊处理 golang
    if [ "$PKG_NAME" = "golang" ]; then
        if [ ! -d "feeds/packages/lang/golang" ]; then
            log_info "添加 $PKG_NAME"
            # 使用完整克隆确保版本兼容性
            if git clone -b 25.x "$PKG_URL" feeds/packages/lang/golang; then
                log_success "$PKG_NAME 添加完成"
                SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
            else
                log_error "$PKG_NAME 添加失败"
                FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
                FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST $PKG_NAME"
            fi
        else
            log_info "$PKG_NAME 已存在，跳过"
            SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
        fi
        continue
    fi
    
    # 处理普通包
    if [ ! -d "$TARGET_DIR" ]; then
        log_info "添加 $PKG_NAME"
        # 使用完整克隆确保包的完整性
        if git clone "$PKG_URL" "$TARGET_DIR"; then
            # 特殊处理需要设置权限的包
            if [ "$PKG_NAME" = "luci-app-athena-led" ]; then
                chmod +x "$TARGET_DIR/root/etc/init.d/athena_led"
                chmod +x "$TARGET_DIR/root/usr/sbin/athena-led"
            fi
            
            # 特殊处理需要修改 Makefile 的包
            if [ "$PKG_NAME" = "luci-app-tailscale" ]; then
                if [ -f "feeds/packages/net/tailscale/Makefile" ]; then
                    sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
                fi
            fi
            
            log_success "$PKG_NAME 添加完成"
            SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
        else
            log_error "$PKG_NAME 添加失败"
            FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
            FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST $PKG_NAME"
        fi
    else
        log_info "$PKG_NAME 已存在，跳过"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
    fi
done

# 3. 添加 small-package 后备仓库（完整克隆）
log_info "添加 Small-Package 后备仓库"
TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
if [ ! -d "$SMALL_PACKAGE_DIR" ]; then
    # 使用完整克隆以确保所有包都可用
    if git clone https://github.com/kenzok8/small-package "$SMALL_PACKAGE_DIR"; then
        log_success "Small-Package 后备仓库添加完成"
        SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
        
        # 调试：列出 small-package 中的所有 luci-app
        log_info "small-package 中的 luci-app 列表："
        find "$SMALL_PACKAGE_DIR" -name "luci-app-*" -type d | sed 's|.*/||' | sort
        
    else
        log_error "克隆 Small-Package 后备仓库失败"
        FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
        FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST small-package"
    fi
else
    log_info "Small-Package 后备仓库已存在，跳过"
    SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
fi

# 4. 智能后备处理
log_step "检查并处理缺失的包"

# 获取配置文件中需要的 LUCI 包
REQUIRED_LUCI_PACKAGES=$(grep "^CONFIG_PACKAGE_luci-app.*=y$" "$CONFIG_FILE" 2>/dev/null | sed 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/' | sort)

log_info "配置文件中需要的 LUCI 包："
echo "$REQUIRED_LUCI_PACKAGES"

# 检查每个需要的包是否存在
for PKG_NAME in $REQUIRED_LUCI_PACKAGES; do
    # 跳过已经在主要源中处理的包
    if [[ -n "${PACKAGE_SOURCES[$PKG_NAME]}" ]]; then
        continue
    fi
    
    # 检查是否在 small-package 后备列表中
    if [[ " ${SMALL_PACKAGE_BACKUP_LIST[*]} " =~ " ${PKG_NAME} " ]]; then
        TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
        
        # 尝试多个可能的源目录
        SOURCE_DIRS=()
        
        # 添加映射的目录
        if [[ -n "${SMALL_PACKAGE_MAPPING[$PKG_NAME]}" ]]; then
            SOURCE_DIRS+=("$SMALL_PACKAGE_DIR/${SMALL_PACKAGE_MAPPING[$PKG_NAME]}")
        fi
        
        # 添加直接命名的目录
        SOURCE_DIRS+=("$SMALL_PACKAGE_DIR/$PKG_NAME")
        
        # 尝试不带 luci-app- 前缀的目录
        if [[ "$PKG_NAME" == luci-app-* ]]; then
            BASE_NAME=${PKG_NAME#luci-app-}
            SOURCE_DIRS+=("$SMALL_PACKAGE_DIR/$BASE_NAME")
        fi
        
        # 尝试查找匹配的目录
        FOUND_SOURCE=""
        for SOURCE_DIR in "${SOURCE_DIRS[@]}"; do
            if [ -d "$SOURCE_DIR" ]; then
                FOUND_SOURCE="$SOURCE_DIR"
                break
            fi
        done
        
        TARGET_DIR="$PACKAGE_DIR/$PKG_NAME"
        
        if [ -n "$FOUND_SOURCE" ] && [ ! -d "$TARGET_DIR" ]; then
            log_info "从 small-package 后备添加: $PKG_NAME (来源: $FOUND_SOURCE)"
            if cp -r "$FOUND_SOURCE" "$TARGET_DIR"; then
                log_success "包 $PKG_NAME 从 small-package 添加成功"
                SUCCESS_PACKAGES=$((SUCCESS_PACKAGES + 1))
                BACKUP_USED_PACKAGES="$BACKUP_USED_PACKAGES $PKG_NAME"
            else
                log_error "包 $PKG_NAME 从 small-package 添加失败"
                FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
                FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST $PKG_NAME"
            fi
        elif [ -d "$TARGET_DIR" ]; then
            log_debug "包 $PKG_NAME 已存在"
        else
            log_warn "包 $PKG_NAME 在 small-package 中不存在"
            # 列出 small-package 中的相关目录以便调试
            if [ -d "$SMALL_PACKAGE_DIR" ]; then
                log_debug "small-package 中相关的目录:"
                find "$SMALL_PACKAGE_DIR" -iname "*${PKG_NAME#luci-app-}*" -type d | head -10
                log_debug "small-package 完整目录列表:"
                find "$SMALL_PACKAGE_DIR" -maxdepth 1 -type d | grep luci-app | head -10
            fi
            FAILED_PACKAGES=$((FAILED_PACKAGES + 1))
            FAILED_PACKAGE_LIST="$FAILED_PACKAGE_LIST $PKG_NAME"
        fi
    fi
done

# --- 更新 feeds ---
log_step "更新软件源"
if ./scripts/feeds update -a; then
    log_success "软件源更新成功"
else
    log_error "软件源更新失败"
    exit 1
fi

log_step "安装软件包"
if ./scripts/feeds install -a; then
    log_success "软件包安装成功"
else
    log_error "软件包安装失败"
    exit 1
fi

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)

# 输出详细摘要
echo -e "\n${CYAN}========== OpenWrt 第三方软件源集成 摘要 ==========${NC}"
echo -e "状态: ${GREEN}成功${NC}"
echo -e "总软件包数: ${TOTAL_PACKAGES}"
echo -e "成功添加: ${GREEN}${SUCCESS_PACKAGES}${NC}"
echo -e "添加失败: ${RED}${FAILED_PACKAGES}${NC}"

if [ $FAILED_PACKAGES -gt 0 ]; then
    echo -e "失败软件包列表: ${RED}${FAILED_PACKAGE_LIST}${NC}"
fi

if [ -n "$BACKUP_USED_PACKAGES" ]; then
    echo -e "使用 small-package 后备的包: ${YELLOW}${BACKUP_USED_PACKAGES}${NC}"
fi

echo -e "开始时间: $(date -d @$SCRIPT_START_TIME '+%Y-%m-%d %H:%M:%S')"
echo -e "结束时间: $(date -d @$SCRIPT_END_TIME '+%Y-%m-%d %H:%M:%S')"

DURATION=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))
echo -e "耗时: ${MINUTES}分${SECONDS}秒"
echo -e "${CYAN}=============================================${NC}\n"

log_success "OpenWrt 第三方软件源集成完成"
