#!/bin/bash

# 导入通用函数
source "$(dirname "$0")/common.sh"

# =================================================================
# DIY Part 1: OpenWrt 初始配置脚本
# 功能: 修改默认IP、主机名、编译署名、主题样式等
# =================================================================

# --- 在此修改初始管理配置 ---
# 默认 LAN IP 地址
LAN_IP="192.168.111.1"
# 默认主机名
HOSTNAME="WRT"
# 编译署名
BUILDER_NAME="Mary"
# 是否应用Argon主题优化 (true/false)
APPLY_ARGON_TWEAKS=true

# --- 脚本逻辑 ---
OPENWRT_ROOT_DIR="$1"

log_info "开始执行 DIY Part 1: 初始配置"

if [ -z "$OPENWRT_ROOT_DIR" ]; then
    log_error "未指定 OpenWrt 根目录！"
    exit 1
fi

if [ ! -d "$OPENWRT_ROOT_DIR" ]; then
    log_error "OpenWrt 根目录不存在: $OPENWRT_ROOT_DIR"
    exit 1
fi

# 1. 修改默认IP地址
log_info "正在设置 LAN IP 为: ${LAN_IP}"
sed -i "s/192.168.1.1/${LAN_IP}/g" "$OPENWRT_ROOT_DIR/package/base-files/files/bin/config_generate"

# 2. 修改主机名
log_info "正在设置主机名为: ${HOSTNAME}"
sed -i "s/hostname='.*'/hostname='${HOSTNAME}'/g" "$OPENWRT_ROOT_DIR/package/base-files/files/bin/config_generate"

# 3. 添加编译署名
log_info "正在添加编译署名: ${BUILDER_NAME}"
STATUS_JS="$OPENWRT_ROOT_DIR/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$STATUS_JS" ]; then
    sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ Built by ${BUILDER_NAME}')/g" "$STATUS_JS"
else
    log_warn "状态页面JS文件未找到，跳过添加编译署名"
fi

# 4. 修改root密码
log_info "正在设置 root 密码"
# 使用 openssl 生成密码哈希
PASSWORD_HASH=$(openssl passwd -1 "${ROOT_PASSWORD}")
# 替换 shadow 文件中的 root 密码字段
sed -i "s/root:\!/root:${PASSWORD_HASH}/g" "$OPENWRT_ROOT_DIR/package/base-files/files/etc/shadow"

# 5. 应用Argon主题优化
if [ "$APPLY_ARGON_TWEAKS" = "true" ]; then
    log_info "正在应用Argon主题优化..."
    
    # 调整在Argon主题下，概览页面显示/隐藏按钮的样式
    ARGON_CSS="$OPENWRT_ROOT_DIR/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css"
    if [ -f "$ARGON_CSS" ]; then
        log_info "修改Argon主题CSS样式..."
        sed -i '/^\.td\.cbi-section-actions {$/,/^}$/ {
            /^}$/a\
.cbi-section.fade-in .cbi-title {\
  position: relative;\
  min-height: 2.765rem;\
  display: flex;\
  align-items: center\
}\
.cbi-section.fade-in .cbi-title>div:last-child {\
  position: absolute;\
  right: 1rem\
}\
.cbi-section.fade-in .cbi-title>div:last-child span {\
  display: inline-block;\
  position: relative;\
  font-size: 0\
}\
.cbi-section.fade-in .cbi-title>div:last-child span::after {\
  content: "\\e90f";\
  font-family: '\''argon'\'' !important;\
  font-size: 1.1rem;\
  display: inline-block;\
  transition: transform 0.3s ease;\
  -webkit-font-smoothing: antialiased;\
  line-height: 1\
}\
.cbi-section.fade-in .cbi-title>div:last-child span[data-style='\''inactive'\'']::after {\
  transform: rotate(90deg);\
}
        }' "$ARGON_CSS"
    else
        log_warn "Argon主题CSS文件未找到，跳过主题样式修改"
    fi
    
    # 修改状态页面的按钮样式
    INDEX_JS="$OPENWRT_ROOT_DIR/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js"
    if [ -f "$INDEX_JS" ]; then
        log_info "修改状态页面按钮样式..."
        sed -i -e '/btn\.setAttribute(\x27class\x27, include\.hide ? \x27label notice\x27 : \x27label\x27);/d' \
               -e "/\x27class\x27: includes\[i\]\.hide ? \x27label notice\x27 : \x27label\x27,/d" \
               "$INDEX_JS"
    else
        log_warn "状态页面索引JS文件未找到，跳过按钮样式修改"
    fi
else
    log_info "跳过Argon主题优化"
fi

log_success "DIY Part 1 执行完成。"
