#!/bin/bash

# =================================================================
# OpenWrt 第三方软件源集成脚本
# 功能: 带有彩色输出、实时反馈和最终摘要报告
# 作者: Mary 日期：20251104
# =================================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # 无颜色

# --- 统计变量 ---
TOTAL_COUNT=0      # 总处理数
SUCCESS_COUNT=0    # 成功数
FAIL_COUNT=0       # 失败数
SUCCESS_LIST=()    # 成功列表
FAIL_LIST=()       # 失败列表

# --- 日志记录辅助函数 ---
log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# --- 最终摘要报告函数 ---
PRINT_SUMMARY_REPORT() {
    echo -e "\n${BOLD}${BLUE}================================================${NC}"
    echo -e "${BOLD}${BLUE}              第三方软件源集成摘要${NC}"
    echo -e "${BOLD}${BLUE}================================================${NC}"
    echo -e "总计处理软件包: ${YELLOW}${TOTAL_COUNT}${NC}"
    echo -e "成功添加: ${GREEN}${SUCCESS_COUNT}${NC}"
    echo -e "添加失败: ${RED}${FAIL_COUNT}${NC}"

    if [ ${#SUCCESS_LIST[@]} -gt 0 ]; then
        echo -e "\n${GREEN}成功添加的软件包:${NC}"
        printf '  - %s\n' "${SUCCESS_LIST[@]}"
    fi

    if [ ${#FAIL_LIST[@]} -gt 0 ]; then
        echo -e "\n${RED}添加失败的软件包:${NC}"
        printf '  - %s\n' "${FAIL_LIST[@]}"
    fi
    echo -e "${BOLD}${BLUE}================================================${NC}\n"
}

# =================================================================
# 核心功能函数 (已优化日志记录)
# =================================================================

# 函数: 安装和更新软件包
# 参数: $1=包名, $2=仓库地址, $3=分支, $4=特殊处理(pkg/name), $5=自定义删除列表
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)
    local REPO_NAME=${PKG_REPO#*/}
    
    log_info "正在处理软件包: ${BOLD}${PKG_NAME}${NC}"
    log_info "源地址: ${PKG_REPO} (分支: ${PKG_BRANCH})"
    
    # 删除本地可能存在的同名或不同名的旧软件包
    for NAME in "${PKG_LIST[@]}"; do
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ ./package/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                log_info "已删除旧目录: $DIR"
            done <<< "$FOUND_DIRS"
        fi
    done
    
    # 克隆 GitHub 仓库
    log_info "正在克隆仓库到 ./$REPO_NAME..."
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" > /dev/null 2>&1

    # 检查 git clone 是否成功
    if [ $? -ne 0 ]; then
        log_error "克隆 ${PKG_REPO} 失败。请检查网络连接或仓库地址是否正确。"
        return 1 # 返回失败状态
    fi
    log_success "仓库克隆成功。"

    # 处理克隆的仓库
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        log_info "正在从仓库中提取软件包 '$PKG_NAME'..."
        # 查找并复制匹配的包目录到当前目录
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
        log_success "软件包提取完毕，临时目录已清理。"
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        log_info "正在将仓库从 '$REPO_NAME' 重命名为 '$PKG_NAME'..."
        mv -f $REPO_NAME $PKG_NAME
        log_success "重命名成功。"
    fi
    return 0 # 返回成功状态
}

# 函数: 删除 feeds 中的指定软件包
REMOVE_FEEDS_PACKAGES() {
    local PKG_LIST=$1
    log_info "正在从 feeds 中删除指定的软件包..."
    for PKG in $PKG_LIST; do
        rm -rf ../feeds/packages/net/$PKG
        log_info "已删除 feed 包: $PKG"
    done
    log_success "Feed 包删除完成。"
}

# 函数: 修改 Makefile
MODIFY_MAKEFILE() {
    local PKG_PATH=$1
    local PATTERN=$2
    log_info "正在修改 Makefile: $PKG_PATH"
    if [ -f "$PKG_PATH" ]; then
        sed -i "$PATTERN" "$PKG_PATH"
        log_success "Makefile 修改完成。"
    else
        log_warn "在 $PKG_PATH 未找到 Makefile。跳过。"
    fi
}

# 函数: 执行额外脚本
EXECUTE_SCRIPT() {
    local SCRIPT_URL=$1
    log_info "正在执行外部脚本: $SCRIPT_URL"
    bash -c "$(curl -fsSL $SCRIPT_URL)"
    if [ $? -eq 0 ]; then
        log_success "外部脚本执行成功。"
    else
        log_error "外部脚本执行失败。"
    fi
}

# =================================================================
# 主执行逻辑
# =================================================================

echo -e "${BOLD}${BLUE}开始集成 OpenWrt 第三方软件源...${NC}"

# --- 京东云雅典娜LED控制 ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-athena-led ---${NC}"
UPDATE_PACKAGE "athena-led" "NONGFAH/luci-app-athena-led" "main" "name" && \
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led && \
SUCCESS_LIST+=("athena-led") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("athena-led") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- PassWall by xiaorouji ---
echo -e "\n${YELLOW}--- 准备 PassWall 环境 ---${NC}"
REMOVE_FEEDS_PACKAGES "xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria ipt2socks microsocks naiveproxy shadowsocks-libev shadowsocks-rust shadowsocksr-libev simple-obfs tcping trojan-plus tuic-client v2ray-plugin xray-plugin geoview shadow-tls"

TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: passwall-packages ---${NC}"
UPDATE_PACKAGE "passwall-packages" "xiaorouji/openwrt-passwall-packages" "main" "name" && SUCCESS_LIST+=("passwall-packages") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("passwall-packages") && FAIL_COUNT=$((FAIL_COUNT + 1))

rm -rf ../feeds/luci/applications/luci-app-passwall
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-passwall ---${NC}"
UPDATE_PACKAGE "passwall-luci" "xiaorouji/openwrt-passwall" "main" "name" && SUCCESS_LIST+=("luci-app-passwall") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-passwall") && FAIL_COUNT=$((FAIL_COUNT + 1))

TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-passwall2 ---${NC}"
UPDATE_PACKAGE "passwall2-luci" "xiaorouji/openwrt-passwall2" "main" "name" && SUCCESS_LIST+=("luci-app-passwall2") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-passwall2") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- AdGuardHome ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-adguardhome ---${NC}"
UPDATE_PACKAGE "luci-app-adguardhome" "sirpdboy/luci-app-adguardhome" "main" && SUCCESS_LIST+=("luci-app-adguardhome") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-adguardhome") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- ddns-go ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-ddns-go ---${NC}"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main" "name" && SUCCESS_LIST+=("ddns-go") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("ddns-go") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- netdata ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-netdata ---${NC}"
UPDATE_PACKAGE "luci-app-netdata" "sirpdboy/luci-app-netdata" "main" && SUCCESS_LIST+=("luci-app-netdata") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-netdata") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- netspeedtest ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-netspeedtest ---${NC}"
UPDATE_PACKAGE "luci-app-netspeedtest" "sirpdboy/luci-app-netspeedtest" "main" "" "homebox speedtest" && SUCCESS_LIST+=("luci-app-netspeedtest") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-netspeedtest") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- partexp ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-partexp ---${NC}"
UPDATE_PACKAGE "luci-app-partexp" "sirpdboy/luci-app-partexp" "main" && SUCCESS_LIST+=("luci-app-partexp") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-partexp") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- taskplan ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-taskplan ---${NC}"
UPDATE_PACKAGE "luci-app-taskplan" "sirpdboy/luci-app-taskplan" "main" && SUCCESS_LIST+=("luci-app-taskplan") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-taskplan") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- lucky ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-lucky ---${NC}"
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" "main" "name" && SUCCESS_LIST+=("lucky") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("lucky") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- easytier ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-easytier ---${NC}"
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "main" && SUCCESS_LIST+=("luci-app-easytier") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-easytier") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- homeproxy ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: homeproxy ---${NC}"
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main" && SUCCESS_LIST+=("homeproxy") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("homeproxy") && FAIL_COUNT=$((FAIL_COUNT + 1))
EXECUTE_SCRIPT "https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh"

# --- golang & openlist2 ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: packages_lang_golang ---${NC}"
UPDATE_PACKAGE "golang" "sbwml/packages_lang_golang" "main" "name" && SUCCESS_LIST+=("packages_lang_golang") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("packages_lang_golang") && FAIL_COUNT=$((FAIL_COUNT + 1))

TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-openlist2 ---${NC}"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main" "name" && SUCCESS_LIST+=("openlist2") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("openlist2") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- mosdns ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-mosdns ---${NC}"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "name" "" "v2dat" && SUCCESS_LIST+=("mosdns") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("mosdns") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- quickfile ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-quickfile ---${NC}"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main" "name" && SUCCESS_LIST+=("quickfile") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("quickfile") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- momo & nikki ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-momo ---${NC}"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main" "name" && SUCCESS_LIST+=("momo") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("momo") && FAIL_COUNT=$((FAIL_COUNT + 1))

TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-nikki ---${NC}"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main" "name" && SUCCESS_LIST+=("nikki") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("nikki") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- OpenAppFilter ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: OpenAppFilter ---${NC}"
UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "main" "name" && SUCCESS_LIST+=("OpenAppFilter") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("OpenAppFilter") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- OpenClash ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: OpenClash ---${NC}"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg" && SUCCESS_LIST+=("openclash") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("openclash") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- tailscale ---
echo -e "\n${YELLOW}--- 准备 Tailscale 环境 ---${NC}"
MODIFY_MAKEFILE "../feeds/packages/net/tailscale/Makefile" '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;'

TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-tailscale ---${NC}"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main" && SUCCESS_LIST+=("luci-app-tailscale") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-tailscale") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- vnt ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: luci-app-vnt ---${NC}"
UPDATE_PACKAGE "luci-app-vnt" "lmq8267/luci-app-vnt" "main" && SUCCESS_LIST+=("luci-app-vnt") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("luci-app-vnt") && FAIL_COUNT=$((FAIL_COUNT + 1))

# --- small-package (后备) ---
TOTAL_COUNT=$((TOTAL_COUNT + 1))
echo -e "\n${YELLOW}--- [${TOTAL_COUNT}] 添加: small-package (后备) ---${NC}"
UPDATE_PACKAGE "small-package" "kenzok8/small-package" "main" "name" && SUCCESS_LIST+=("small-package") && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAIL_LIST+=("small-package") && FAIL_COUNT=$((FAIL_COUNT + 1))


# =================================================================
# 最终步骤: 打印摘要报告
# =================================================================
PRINT_SUMMARY_REPORT

log_info "脚本执行完毕。"
