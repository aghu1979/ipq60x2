# ==============================================================================
# 原始代码备份（供参考）
# ==============================================================================

# 京东云雅典娜led控制
git clone https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# passwall by xiaorouji，
# 执行 ./scripts/feeds update -a 操作前，在 feeds.conf.default 顶部插入如下代码：
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main

# passwall2 by xiaorouji，
src-git luci-app-passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main


# AdGuardHome，官方推荐OpenWrt LUCI app by @kongfl888 (originally by @rufengsuixing).作为备选
# 首选使用luci-app-adguardhome by sirpdboy
git clone https://github.com/sirpdboy/luci-app-adguardhome package/luci-app-adguardhome
# git clone https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome


# ddns-go by sirpdboy，自带luci-app
git clone https://github.com/sirpdboy/luci-app-ddns-go package/luci-app-ddns-go

# luci-app-netdata by sirpdboy
git clone https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata

# luci-app-netspeedtest by sirpdboy
git clone https://github.com/sirpdboy/luci-app-netspeedtest package/luci-app-netspeedtest

# luci-app-partexp by sirpdboy
git clone https://github.com/sirpdboy/luci-app-partexp package/luci-app-partexp

# luci-app-taskplan by sirpdboy
git clone https://github.com/sirpdboy/luci-app-taskplan package/luci-app-taskplan

# lucky by gdy666，自带luci-app，sirpdboy也有luci-app但是可能与原作者有冲突，使用原作者，sirpdboy备选
git clone https://github.com/gdy666/luci-app-lucky package/lucky
# git clone https://github.com/sirpdboy/luci-app-lucky package/lucky

# luci-app-easytier
git clone https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier

# frp https://github.com/fatedier/frp，无luci-app，建议使用small-package更新

# homeproxy immortalwrt官方出品，无luci-app，建议使用https://github.com/VIKINGYFY/homeproxy更新
git clone https://github.com/VIKINGYFY/homeproxy package/homeproxy
# 一个更方便地生成 ImmortalWrt/OpenWrt(23.05.x+) HomeProxy 插件大多数常用配置的脚本。
# (必备) 通过私密 Gist 或其它可被正常访问的私有链接定制你的专属 rules.sh 配置内容；
# 执行以下命令（脚本执行期间会向你索要你的定制配置URL）：bash -c "$(curl -fsSl https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh)"

# golang & luci-app-openlist2 by sbwml
git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
git clone https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist

# luci-app-mosdns by sbwml
git clone -b v5 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# luci-app-quickfile by sbwml
git clone https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile

# luci-app-istorex（向导模式及主体）/luci-app-quickstart（网络向导和首页界面）/luci-app-diskman （磁盘管理），建议使用small-package更新

# momo在 OpenWrt 上使用 sing-box 进行透明代理/nikki在 OpenWrt 上使用 Mihomo 进行透明代理。
echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo;main" >> "feeds.conf.default"
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki;main" >> "feeds.conf.default"
# git clone https://github.com/nikkinikki-org/OpenWrt-momo package/luci-app-momo
# git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# OpenAppFilter（OAF），自带luci-app
git clone https://github.com/destan19/OpenAppFilter package/luci-app-oaf

# luci-app-openclash by vernesong
src-git luci-app-openclash https://github.com/vernesong/OpenClash.git
# # 从 OpenWrt 的 SDK 编译
# # 解压下载好的 SDK
# curl -SLk --connect-timeout 30 --retry 2 "https://archive.openwrt.org/chaos_calmer/15.05.1/ar71xx/generic/OpenWrt-SDK-15.05.1-ar71xx-generic_gcc-4.8-linaro_uClibc-0.9.33.2.Linux-x86_64.tar.bz2" -o "/tmp/SDK.tar.bz2"
# cd \tmp
# tar xjf SDK.tar.bz2
# cd OpenWrt-SDK-15.05.1-*
# 
# # Clone 项目
# mkdir package/luci-app-openclash
# cd package/luci-app-openclash
# git init
# git remote add -f origin https://github.com/vernesong/OpenClash.git
# git config core.sparsecheckout true
# echo "luci-app-openclash" >> .git/info/sparse-checkout
# git pull --depth 1 origin master
# git branch --set-upstream-to=origin/master master
# 
# # 编译 po2lmo (如果有po2lmo可跳过)
# pushd luci-app-openclash/tools/po2lmo
# make && sudo make install
# popd
# 
# # 开始编译
# 
# # 先回退到SDK主目录
# cd ../..
# make package/luci-app-openclash/luci-app-openclash/compile V=99
# 
# # IPK文件位置
# ./bin/ar71xx/packages/base/luci-app-openclash_*-beta_all.ipk
# # 同步源码
# cd package/luci-app-openclash/luci-app-openclash
# git pull
# 
# # 您也可以直接拷贝 `luci-app-openclash` 文件夹至其他 `OpenWrt` 项目的 `Package` 目录下随固件编译
# 
# make menuconfig
# # 选择要编译的包 LuCI -> Applications -> luci-app-openclash

# tailscale，官方推荐luci-app-tailscale by asvow
sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;' feeds/packages/net/tailscale/Makefile
git clone https://github.com/asvow/luci-app-tailscale package/luci-app-tailscale

# vnt，官方https://github.com/vnt-dev/vnt，无luci-app，使用lmq8267
git clone https://github.com/lmq8267/luci-app-vnt package/luci-app-vnt

# kenzok8/small-package，后备之选，只有上述的ipk地址缺失才会用到。
git clone https://github.com/kenzok8/small-package small
