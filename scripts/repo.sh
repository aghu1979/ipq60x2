#!/bin/bash

# 安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
    local REPO_NAME=${PKG_REPO#*/}
    
    echo " "
    
    # 删除本地可能存在的不同名称的软件包
    for NAME in "${PKG_LIST[@]}"; do
        # 查找匹配的目录
        echo "Search directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
        
        # 删除找到的目录
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "Delete directory: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "Not found directory: $NAME"
        fi
    done
    
    # 克隆 GitHub 仓库
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"
    
    # 处理克隆的仓库
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# 特殊处理函数 - 删除feeds中的包
REMOVE_FEEDS_PACKAGES() {
    local PKG_LIST=$1
    echo "Removing packages from feeds..."
    for PKG in $PKG_LIST; do
        rm -rf ../feeds/packages/net/$PKG
        echo "Removed: $PKG"
    done
}

# 特殊处理函数 - 修改Makefile
MODIFY_MAKEFILE() {
    local PKG_PATH=$1
    local PATTERN=$2
    if [ -f "$PKG_PATH" ]; then
        sed -i "$PATTERN" "$PKG_PATH"
        echo "Modified: $PKG_PATH"
    fi
}

# 特殊处理函数 - 执行额外脚本
EXECUTE_SCRIPT() {
    local SCRIPT_URL=$1
    echo "Executing script from: $SCRIPT_URL"
    bash -c "$(curl -fsSL $SCRIPT_URL)"
}

# 主题类
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"

# 网络工具类
UPDATE_PACKAGE "athena-led" "NONGFAH/luci-app-athena-led" "main" "name"
# 设置权限
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# PassWall 相关
REMOVE_FEEDS_PACKAGES "xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria ipt2socks microsocks naiveproxy shadowsocks-libev shadowsocks-rust shadowsocksr-libev simple-obfs tcping trojan-plus tuic-client v2ray-plugin xray-plugin geoview shadow-tls"
UPDATE_PACKAGE "passwall-packages" "xiaorouji/openwrt-passwall-packages" "main" "name"
rm -rf ../feeds/luci/applications/luci-app-passwall
UPDATE_PACKAGE "passwall-luci" "xiaorouji/openwrt-passwall" "main" "name"
UPDATE_PACKAGE "passwall2-luci" "xiaorouji/openwrt-passwall2" "main" "name"

# AdGuardHome
UPDATE_PACKAGE "luci-app-adguardhome" "sirpdboy/luci-app-adguardhome" "main"

# DDNS相关
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"

# 监控和测试工具
UPDATE_PACKAGE "luci-app-netdata" "sirpdboy/luci-app-netdata" "main"
UPDATE_PACKAGE "luci-app-netspeedtest" "sirpdboy/luci-app-netspeedtest" "main" "" "homebox speedtest"

# 系统工具
UPDATE_PACKAGE "luci-app-partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "luci-app-taskplan" "sirpdboy/luci-app-taskplan" "main"

# 端口转发和代理工具
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" "main" "name"
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "main"

# HomeProxy
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
# 执行HomeProxy配置脚本
EXECUTE_SCRIPT "https://raw.githubusercontent.com/thisIsIan-W/homeproxy-autogen-configuration/refs/heads/main/generate_homeproxy_rules.sh"

# Golang相关
UPDATE_PACKAGE "golang" "sbwml/packages_lang_golang" "main" "name"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"

# DNS工具
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"

# 文件管理
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"

# 透明代理工具
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"

# 应用过滤
UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "main" "name"

# OpenClash
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"

# Tailscale
MODIFY_MAKEFILE "../feeds/packages/net/tailscale/Makefile" '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d;'
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# VNT
UPDATE_PACKAGE "luci-app-vnt" "lmq8267/luci-app-vnt" "main"

# 后备软件包
UPDATE_PACKAGE "small-package" "kenzok8/small-package" "main" "name"

# 更新软件包版本
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")
    
    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi
    
    echo -e "\n$PKG_NAME version update has started!"
    
    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")
        
        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")
        
        local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
        
        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)
        
        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"
        
        if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been updated!"
        else
            echo "$PKG_FILE version is already the latest!"
        fi
    done
}

# 更新特定软件包版本
# UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
# UPDATE_VERSION "sing-box"
# UPDATE_VERSION "tailscale"
