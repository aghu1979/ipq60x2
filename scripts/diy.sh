#!/bin/bash

# ==============================================================================
# OpenWrt 自定义编译脚本
# 版本: v2.3
# 日期: 2025-11-18
# 功能: 修改系统配置、添加自定义软件源、更新并安装软件包
# 作者: Mary
# ==============================================================================

# --- 1. 修改系统默认配置 ---
echo ">>> 步骤 1/5: 修改系统默认配置"
# 修改默认IP地址
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
# 修改设备主机名
sed -i "s/hostname='.*'/hostname='WRT'/g" package/base-files/files/bin/config_generate
# 在Luci系统概览页面添加编译者信息
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Built by Mary')/g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
# 删除luci-app-attendedsysupgrade在概览页面的升级提示
rm -rf feeds/luci/applications/luci-app-attendedsysupgrade/htdocs/luci-static/resources/view/status/include/11_upgrades.js

# --- 2. 预删除将要被替换的软件包 ---
echo ">>> 步骤 2/5: 预清理旧的软件包和Feeds，避免冲突"
# 定义一个包含所有将要添加的软件包路径的数组
packages_to_remove=(
    # 将通过 git clone 添加到 package/ 目录的包
    "package/luci-app-athena-led"
    "package/luci-app-adguardhome"
    "package/luci-app-ddns-go"
    "package/luci-app-netdata"
    "package/luci-app-netspeedtest"
    "package/luci-app-partexp"
    "package/luci-app-taskplan"
    "package/lucky"
    "package/luci-app-easytier"
    "package/homeproxy"
    "package/luci-app-openlist"
    "package/luci-app-mosdns"
    "package/luci-app-quickfile"
    "package/luci-app-oaf"
    "package/luci-app-tailscale"
    "package/luci-app-vnt"
    # 【修正】从正确的上游 (linkease) 添加的 iStore 相关软件包
    "package/luci-app-istorex"
    "package/luci-app-quickstart"
    "package/luci-app-diskman"
    # 将通过 git_sparse_clone 添加或移动的包
    "feeds/packages/net/ariang"
    "feeds/packages/net/frp"
    "feeds/luci/applications/luci-app-frpc"
    "feeds/luci/applications/luci-app-frps"
    "feeds/luci/themes/luci-theme-argon"
    "feeds/luci/themes/luci-theme-aurora"
    # Golang 语言包
    "feeds/packages/lang/golang"
)

# 遍历数组并删除
for pkg_path in "${packages_to_remove[@]}"; do
    if [ -d "$pkg_path" ]; then
        echo "  - 删除旧包: $pkg_path"
        rm -rf "$pkg_path"
    fi
done

# --- 3. 添加自定义软件源 ---
echo ">>> 步骤 3/5: 添加自定义软件源到 feeds.conf.default"
# 函数：用于添加软件源，避免重复添加
add_feed() {
    local feed_name="$1"
    local feed_url="$2"
    local feed_branch="${3:-main}"
    local feed_entry="src-git $feed_name $feed_url;$feed_branch"
    
    if ! grep -qF "src-git $feed_name" feeds.conf.default; then
        echo "  - 添加软件源: $feed_name"
        echo "$feed_entry" >> feeds.conf.default
    else
        echo "  - 软件源已存在，跳过: $feed_name"
    fi
}

# 添加各种自定义软件源
add_feed "passwall_packages" "https://github.com/xiaorouji/openwrt-passwall-packages.git"
add_feed "passwall_luci" "https://github.com/xiaorouji/openwrt-passwall.git"
add_feed "luci-app-passwall2" "https://github.com/xiaorouji/openwrt-passwall2.git"
add_feed "luci-app-openclash" "https://github.com/vernesong/OpenClash.git"
add_feed "momo" "https://github.com/nikkinikki-org/OpenWrt-momo"
add_feed "nikki" "https://github.com/nikkinikki-org/OpenWrt-nikki"

# --- 4. 克隆或更新软件包源码 ---
echo ">>> 步骤 4/5: 克隆软件包源码"
# Git稀疏克隆函数
git_sparse_clone() {
    branch="$1" repourl="$2" && shift 2
    echo "  - 稀疏克隆: $repourl ($branch) -> $@"
    git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
    repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
    cd $repodir && git sparse-checkout set $@
    mv -f $@ ../
    cd .. && rm -rf $repodir
}

# --- 4.1 直接克隆到 package/ 目录 ---
echo "  >> 直接克隆软件包..."
# Sirpdboy 的软件包集合
git clone --depth=1 https://github.com/sirpdboy/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go package/luci-app-ddns-go
git clone --depth=1 https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest
git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp package/luci-app-partexp
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan package/luci-app-taskplan

# 【修正】从正确的上游 (linkease/iStore) 克隆，源自 small-package 推荐
echo "  >> 从 iStore 仓库克隆软件包 (源自 small-package 推荐)..."
git clone --depth=1 https://github.com/linkease/luci-app-istorex package/luci-app-istorex
git clone --depth=1 https://github.com/linkease/luci-app-quickstart package/luci-app-quickstart
git clone --depth=1 https://github.com/linkease/luci-app-diskman package/luci-app-diskman

# 其他作者的独立软件包
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/lucky
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy package/homeproxy
git clone --depth=1 https://github.com/destan19/OpenAppFilter package/luci-app-oaf
git clone --depth=1 https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale
git clone --depth=1 https://github.com/lmq8267/luci-app-vnt package/luci-app-vnt

# SBWML 的软件包集合
git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns
git clone --depth=1 https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# --- 4.2 使用稀疏克隆并移动到指定目录 ---
echo "  >> 稀疏克隆并移动软件包..."
# 主题
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
mv -f package/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora package/luci-theme-aurora
mv -f package/luci-theme-aurora feeds/luci/themes/luci-theme-aurora

# FRP (后端和Luci前端)
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
mv -f net/ariang feeds/packages/net/
git_sparse_clone frp https://github.com/laipeng668/packages net/frp
mv -f net/frp feeds/packages/net/
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f applications/luci-app-frpc feeds/luci/applications/
mv -f applications/luci-app-frps feeds/luci/applications/

# 克隆 small-package 作为备用参考
git clone --depth=1 https://github.com/kenzok8/small-package small

# --- 5. 更新与安装Feeds ---
echo ">>> 步骤 5/5: 更新并安装所有软件包"
./scripts/feeds update -a
./scripts/feeds install -a

echo "=============================================================================="
echo "自定义脚本执行完成！"
echo "=============================================================================="
