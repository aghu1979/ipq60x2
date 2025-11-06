#!/bin/bash
# =============================================================================
# OpenWrt 第三方软件源集成脚本
# 版本: 2.0
# 描述: 集成第三方软件源，处理包冲突，提供后备仓库
# =============================================================================

# 加载通用函数库
source "$(dirname "$0")/common.sh"

# 全局变量
REPO_PATH="${REPO_PATH:-$(pwd)}"
FEEDS_CONF="$REPO_PATH/feeds.conf.default"
BACKUP_REPO="https://github.com/kenzok8/small-package"

# 软件源列表
THIRD_PARTY_FEEDS=(
    # 京东云雅典娜LED控制
    "luci-app-athena-led|https://github.com/NONGFAH/luci-app-athena-led|package/luci-app-athena-led"
    
    # PassWall by xiaorouji
    "passwall-packages|https://github.com/xiaorouji/openwrt-passwall-packages|package/passwall-packages"
    "passwall-luci|https://github.com/xiaorouji/openwrt-passwall|package/passwall-luci"
    "passwall2-luci|https://github.com/xiaorouji/openwrt-passwall2|package/passwall2-luci"
    
    # AdGuardHome by sirpdboy
    "luci-app-adguardhome|https://github.com/sirpdboy/luci-app-adguardhome.git|package/luci-app-adguardhome"
    
    # ddns-go by sirpdboy
    "ddns-go|https://github.com/sirpdboy/luci-app-ddns-go.git|package/ddns-go"
    
    # netdata by sirpdboy
    "luci-app-netdata|https://github.com/sirpdboy/luci-app-netdata|package/luci-app-netdata"
    
    # netspeedtest by sirpdboy
    "luci-app-netspeedtest|https://github.com/sirpdboy/luci-app-netspeedtest|package/luci-app-netspeedtest"
    
    # partexp by sirpdboy
    "luci-app-partexp|https://github.com/sirpdboy/luci-app-partexp.git|package/luci-app-partexp"
    
    # taskplan by sirpdboy
    "luci-app-taskplan|https://github.com/sirpdboy/luci-app-taskplan|package/luci-app-taskplan"
    
    # lucky by gdy666
    "lucky|https://github.com/gdy666/luci-app-lucky.git|package/lucky"
    
    # easytier
    "luci-app-easytier|https://github.com/EasyTier/luci-app-easytier.git|package/luci-app-easytier"
    
    # homeproxy
    "homeproxy|https://github.com/VIKINGYFY/homeproxy|package/homeproxy"
    
    # golang & openlist2 by sbwml
    "packages_lang_golang|https://github.com/sbwml/packages_lang_golang|feeds/packages/lang/golang|25.x"
    "openlist|https://github.com/sbwml/luci-app-openlist2|package/openlist"
    
    # mosdns by sbwml
    "mosdns|https://github.com/sbwml/luci-app-mosdns|package/mosdns|v5"
    
    # quickfile by sbwml
    "quickfile|https://github.com/sbwml/luci-app-quickfile|package/quickfile"
    
    # momo & nikki
    "luci-app-momo|https://github.com/nikkinikki-org/OpenWrt-momo|package/luci-app-momo"
    "luci-app-nikki|https://github.com/nikkinikki-org/OpenWrt-nikki|package/luci-app-nikki"
    
    # OpenAppFilter
    "OpenAppFilter|https://github.com/destan19/OpenAppFilter.git|package/OpenAppFilter"
    
    # OpenClash
    "luci-app-openclash|https://github.com/vernesong/OpenClash.git|package/luci-app-openclash|dev"
    
    # tailscale
    "luci-app-tailscale|https://github.com/asvow/luci-app-tailscale|package/luci-app-tailscale"
    
    # vnt
    "luci-app-vnt|https://github.com/lmq8267/luci-app-vnt.git|package/luci-app-vnt"
    
    # 后备仓库
    "small-package|https://github.com/kenzok8/small-package|small"
)

# 冲突包列表（官方feeds中可能存在的包）
CONFLICT_PACKAGES=(
    # PassWall相关
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
    "geoview"
    "shadow-tls"
    
    # 其他可能冲突的包
    "luci-app-passwall"
    "luci-app-passwall2"
    "luci-app-openclash"
    "luci-app-adguardhome"
    "tailscale"
)

log_work "开始集成第三方软件源..."

# 备份原始feeds文件
backup_feeds() {
    log_info "备份原始feeds配置..."
    
    if [ -f "$FEEDS_CONF" ]; then
        backup_file "$FEEDS_CONF"
    else
        log_warning "原始feeds配置文件不存在"
    fi
}

# 清理冲突包
clean_conflicting_packages() {
    log_info "清理可能冲突的软件包..."
    
    local conflict_count=0
    
    # 清理feeds中的冲突包
    for package in "${CONFLICT_PACKAGES[@]}"; do
        local found_packages=$(find "$REPO_PATH/feeds/packages" -name "$package" -type d 2>/dev/null)
        
        if [ -n "$found_packages" ]; then
            log_package "发现feeds中的冲突包: $package"
            echo "$found_packages" | while read pkg_path; do
                log_warning "删除: $pkg_path"
                rm -rf "$pkg_path"
                ((conflict_count++))
            done
        fi
        
        # 清理package目录中的冲突包
        found_packages=$(find "$REPO_PATH/package" -name "$package" -type d 2>/dev/null)
        
        if [ -n "$found_packages" ]; then
            log_package "发现package中的冲突包: $package"
            echo "$found_packages" | while read pkg_path; do
                log_warning "删除: $pkg_path"
                rm -rf "$pkg_path"
                ((conflict_count++))
            done
        fi
    done
    
    log_success "清理完成，处理了 $conflict_count 个冲突包"
}

# 克隆单个软件源
clone_feed() {
    local name=$1
    local url=$2
    local target=$3
    local branch=${4:-""}
    
    log_package "克隆 $name..."
    
    if [ -n "$branch" ]; then
        git clone --depth=1 -b "$branch" "$url" "$target" 2>/dev/null || {
            log_error "克隆失败: $name ($url)"
            return 1
        }
    else
        git clone --depth=1 "$url" "$target" 2>/dev/null || {
            log_error "克隆失败: $name ($url)"
            return 1
        }
    fi
    
    # 特殊处理
    case "$name" in
        "luci-app-athena-led")
            chmod +x "$target/root/etc/init.d/athena_led" "$target/root/usr/sbin/athena-led"
            ;;
        "tailscale")
            sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' "$REPO_PATH/feeds/packages/net/tailscale/Makefile"
            ;;
    esac
    
    log_success "克隆成功: $name"
    return 0
}

# 添加第三方软件源
add_third_party_feeds() {
    log_info "添加第三方软件源..."
    
    local success_count=0
    local fail_count=0
    
    for feed in "${THIRD_PARTY_FEEDS[@]}"; do
        IFS='|' read -r name url target branch <<< "$feed"
        
        # 创建目标目录
        mkdir -p "$REPO_PATH/$(dirname "$target")"
        
        if clone_feed "$name" "$url" "$REPO_PATH/$target" "$branch"; then
            ((success_count++))
        else
            ((fail_count++))
            # 如果克隆失败，尝试使用后备仓库
            if [ "$name" != "small-package" ]; then
                log_warning "尝试使用后备仓库..."
                if clone_feed "$name-backup" "$BACKUP_REPO" "$REPO_PATH/small"; then
                    log_success "后备仓库克隆成功"
                fi
            fi
        fi
    done
    
    log_info "软件源添加完成: 成功 $success_count 个，失败 $fail_count 个"
}

# 更新feeds
update_feeds() {
    log_info "更新软件源..."
    
    cd "$REPO_PATH"
    
    # 清理旧的feeds
    log_work "清理旧的feeds..."
    ./scripts/feeds clean > /dev/null 2>&1
    
    # 更新feeds
    log_work "从远程更新feeds..."
    if ./scripts/feeds update -a; then
        log_success "feeds更新成功"
    else
        log_warning "部分feeds更新失败，继续执行..."
    fi
    
    # 安装feeds
    log_work "安装feeds..."
    if ./scripts/feeds install -a; then
        log_success "feeds安装成功"
    else
        log_warning "部分feeds安装失败，继续执行..."
    fi
}

# 生成软件源报告
generate_feeds_report() {
    log_info "生成软件源报告..."
    
    local report_file="$REPO_PATH/feeds_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=================================================================="
        echo "第三方软件源集成报告"
        echo "=================================================================="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "源码路径: $REPO_PATH"
        echo ""
        
        echo "【已集成的软件源】"
        echo "----------------------------------------"
        for feed in "${THIRD_PARTY_FEEDS[@]}"; do
            IFS='|' read -r name url target branch <<< "$feed"
            echo "- $name: $url"
            [ -n "$branch" ] && echo "  分支: $branch"
        done
        echo ""
        
        echo "【已清理的冲突包】"
        echo "----------------------------------------"
        for package in "${CONFLICT_PACKAGES[@]}"; do
            echo "- $package"
        done
        echo ""
        
        echo "【包统计】"
        echo "----------------------------------------"
        echo "Luci应用包: $(find "$REPO_PATH/package" -path "*/luci-app-*" -name "Makefile" | wc -l)"
        echo "主题包: $(find "$REPO_PATH/package" -path "*/luci-theme-*" -name "Makefile" | wc -l)"
        echo "协议包: $(find "$REPO_PATH/package" -path "*/luci-proto-*" -name "Makefile" | wc -l)"
        echo "国际化包: $(find "$REPO_PATH/package" -path "*/luci-i18n-*" -name "Makefile" | wc -l)"
        echo ""
        
        echo "【后备仓库】"
        echo "----------------------------------------"
        echo "URL: $BACKUP_REPO"
        echo "状态: 已准备"
        echo ""
        
        echo "=================================================================="
        
    } > "$report_file"
    
    log_success "软件源报告已生成: $report_file"
}

# 验证集成结果
verify_integration() {
    log_info "验证集成结果..."
    
    local error_count=0
    
    # 检查关键包是否存在
    local key_packages=(
        "luci-app-athena-led"
        "luci-app-passwall"
        "luci-app-openclash"
        "luci-app-adguardhome"
        "luci-app-tailscale"
    )
    
    for package in "${key_packages[@]}"; do
        if [ ! -d "$REPO_PATH/package/$package" ] && [ ! -d "$REPO_PATH/small/$package" ]; then
            log_warning "关键包缺失: $package"
            ((error_count++))
        fi
    done
    
    if [ $error_count -eq 0 ]; then
        log_success "集成验证通过"
    else
        log_warning "发现 $error_count 个问题"
    fi
}

# 主函数
main() {
    log_work "开始软件源集成流程..."
    
    # 检查网络
    check_network || exit 1
    
    # 执行集成步骤
    backup_feeds
    clean_conflicting_packages
    add_third_party_feeds
    update_feeds
    generate_feeds_report
    verify_integration
    
    log_success "软件源集成完成！"
    log_info "可以使用 'make defconfig' 更新配置"
}

# 执行主函数
main "$@"
