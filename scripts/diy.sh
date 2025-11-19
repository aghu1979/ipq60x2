# scripts/diy.sh
# =============================================================================
# ImmortalWrt 固件自定义脚本
# 版本: 1.0.8
# 更新日期: 2025-11-19
# =============================================================================

# --- 1. 基础系统修改 ---
echo ">>> 1. 修改默认IP、主机名和编译署名..."
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='WRT'/g" package/base-files/files/bin/config_generate
# 修复 sed 命令，使用 | 作为分隔符，避免与内容中的 / 冲突
sed -i "s|(\(luciversion || ''\))|(\1) + (' / Built by Mary')|g" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# 删除luci-app-attendedsysupgrade在概览页面的升级提示
echo ">>> 删除luci-app-attendedsysupgrade升级提示..."
rm -rf feeds/luci/applications/luci-app-attendedsysupgrade/htdocs/luci-static/resources/view/status/include/11_upgrades.js

# --- 2. 移除旧包，为新包做准备 ---
echo ">>> 2. 移除即将被替换的旧软件包..."
PACKAGES_TO_REMOVE=(
    "feeds/luci/applications/luci-app-wechatpush"
    "feeds/luci/applications/luci-app-appfilter"
    "feeds/luci/applications/luci-app-frpc"
    "feeds/luci/applications/luci-app-frps"
    "feeds/luci/themes/luci-theme-argon"
    "feeds/packages/net/open-app-filter"
    "feeds/packages/net/adguardhome"
    "feeds/packages/net/ariang"
    "feeds/packages/net/frp"
    "feeds/packages/lang/golang"
)

for package in "${PACKAGES_TO_REMOVE[@]}"; do
    if [ -d "$package" ]; then
        echo "  - 移除: $package"
        rm -rf "$package"
    fi
done

# --- 3. 定义Git稀疏克隆函数 ---
function git_sparse_clone() {
    branch="$1"
    repourl="$2"
    shift 2
    
    echo ">>> 稀疏克隆 $repourl (分支: $branch, 目录: $@)"
    
    # 检查仓库是否存在
    if ! git ls-remote --exit-code "$repourl" &>/dev/null; then
        echo "错误: 仓库 $repourl 不存在或无法访问"
        return 1
    fi
    
    # 获取仓库名
    repodir=$(echo "$repourl" | awk -F '/' '{print $(NF)}')
    
    # 克隆仓库
    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
    
    # 进入仓库目录并设置稀疏检出
    cd "$repodir" || return 1
    git sparse-checkout set $@
    
    # 移动文件到目标目录
    for dir in "$@"; do
        if [ -d "$dir" ]; then
            echo "  - 移动 $dir -> ../package"
            mv -f "$dir" ../package/
        else
            echo "  - 警告: 目录 $dir 不存在于仓库中"
        fi
    done
    
    # 返回上级目录并删除克隆的仓库
    cd ..
    rm -rf "$repodir"
    
    echo "<<< 稀疏克隆完成"
}

# --- 4. 克隆第三方软件包 ---
echo ">>> 4. 开始克隆第三方软件包..."

# ariang & frp & AdGuardHome & WolPlus & Argon & Aurora & Go & OpenList & Lucky & wechatpush & OpenAppFilter & 集客无线AC控制器 & 雅典娜LED控制
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git_sparse_clone frp https://github.com/laipeng668/packages net/frp
mv -f package/frp feeds/packages/net/frp
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f package/luci-app-frpc feeds/luci/applications/luci-app-frpc
mv -f package/luci-app-frps feeds/luci/applications/luci-app-frps
git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2

# --- 5. Mary 软件源 ---
echo ">>> 5. 添加 Mary 及其他精选软件源..."

# 京东云雅典娜LED控制
echo "  - 克隆 luci-app-athena-led"
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# Argon & Aurora主题
echo "  - 克隆主题"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora

# PassWall & PassWall2
echo "  - 添加 PassWall & PassWall2 软件源"
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> "feeds.conf.default"
echo "src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main" >> "feeds.conf.default"
echo "src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main" >> "feeds.conf.default"

# AdGuardHome (sirpdboy's version)
echo "  - 克隆 luci-app-adguardhome"
git clone --depth=1 https://github.com/sirpdboy/luci-app-adguardhome package/luci-app-adguardhome

# ddns-go (sirpdboy's version)
echo "  - 克隆 luci-app-ddns-go"
git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go package/luci-app-ddns-go

# netdata, netspeedtest, partexp, taskplan (sirpdboy's versions)
echo "  - 克隆 sirpdboy 的系列工具"
git clone --depth=1 https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest
git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp package/luci-app-partexp
git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan package/luci-app-taskplan

# lucky (gdy666's version)
echo "  - 克隆 luci-app-lucky"
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/luci-app-lucky

# luci-app-easytier
echo "  - 克隆 luci-app-easytier"
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier

# homeproxy
echo "  - 克隆 homeproxy"
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy package/homeproxy

# luci-app-mosdns & v2ray-geodata (sbwml's version)
echo "  - 克隆 luci-app-mosdns"
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone --depth=1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# luci-app-quickfile (sbwml's version)
echo "  - 克隆 luci-app-quickfile"
git clone --depth=1 https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# momo & nikki
echo "  - 添加 momo & nikki 软件源"
echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo;main" >> "feeds.conf.default"
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki;main" >> "feeds.conf.default"

# OpenClash
echo "  - 克隆 OpenClash"
git_sparse_clone openclash https://github.com/vernesong/OpenClash package/openclash

# Tailscale (asvow's version)
echo "  - 克隆 luci-app-tailscale"
sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
git clone --depth=1 https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# vnt
echo "  - 克隆 luci-app-vnt"
git clone --depth=1 https://github.com/lmq8267/luci-app-vnt package/luci-app-vnt

# kenzok8/small-package (备用)
echo "  - 克隆 small-package (备用)"
git clone --depth=1 https://github.com/kenzok8/small-package small

# --- 6. 更新和安装Feeds ---
echo ">>> 6. 更新和安装所有Feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

echo ">>> DIY脚本执行完成！"
