# scripts/diy.sh
#!/bin/bash

# ==============================================================================
# DIY Part: OpenWrt 初始配置脚本
#
# 功能:
#   修改默认IP、主机名、编译署名、主题样式等
#   为OpenWrt固件提供初始配置
#
# 使用方法:
#   ./diy.sh [OpenWrt根目录]
#
# 作者: Mary
# 日期：20251104
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 默认 LAN IP 地址
LAN_IP="192.168.111.1"
# 默认主机名
HOSTNAME="WRT"
# 默认 root 用户密码
ROOT_PASSWORD="password"
# 编译署名
BUILDER_NAME="Mary"
# 是否应用Argon主题优化 (true/false)
APPLY_ARGON_TWEAKS=true

# --- 脚本逻辑 ---
OPENWRT_ROOT_DIR="$1"

# 记录开始时间
SCRIPT_START_TIME=$(date +%s)

log_step "开始执行 DIY Part 初始配置"

# 显示系统资源使用情况
show_system_resources

# 检查参数
check_var_not_empty "OPENWRT_ROOT_DIR" "$OPENWRT_ROOT_DIR" "未指定 OpenWrt 根目录！"

# 检查目录是否存在
check_dir_exists "$OPENWRT_ROOT_DIR" "OpenWrt 根目录不存在: $OPENWRT_ROOT_DIR"

# 检查OpenWrt环境
check_openwrt_env "$OPENWRT_ROOT_DIR"

# 提取设备配置信息
extract_device_info "$OPENWRT_ROOT_DIR/.config" "$OPENWRT_ROOT_DIR/device_info.txt"

# 1. 修改默认IP地址
log_substep "设置 LAN IP 为: ${LAN_IP}"
CONFIG_GENERATE_FILE="$OPENWRT_ROOT_DIR/package/base-files/files/bin/config_generate"
check_file_exists "$CONFIG_GENERATE_FILE" "配置生成文件不存在: $CONFIG_GENERATE_FILE"
safe_replace "$CONFIG_GENERATE_FILE" "192.168.1.1" "$LAN_IP"

# 2. 修改主机名
log_substep "设置主机名为: ${HOSTNAME}"
safe_replace "$CONFIG_GENERATE_FILE" "hostname='.*'" "hostname='${HOSTNAME}'"

# 3. 添加编译署名
log_substep "添加编译署名: ${BUILDER_NAME}"
STATUS_JS="$OPENWRT_ROOT_DIR/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$STATUS_JS" ]; then
    safe_replace "$STATUS_JS" "(\(luciversion || ''\))" "(\1) + (' \/ Built by ${BUILDER_NAME}')"
else
    log_warn "状态页面JS文件未找到，跳过添加编译署名"
fi

# 4. 修改root密码
log_substep "设置 root 密码"
SHADOW_FILE="$OPENWRT_ROOT_DIR/package/base-files/files/etc/shadow"
check_file_exists "$SHADOW_FILE" "Shadow文件不存在: $SHADOW_FILE"

# 使用 openssl 生成密码哈希
if command -v openssl &> /dev/null; then
    PASSWORD_HASH=$(openssl passwd -1 "${ROOT_PASSWORD}")
    safe_replace "$SHADOW_FILE" "root:\!" "root:${PASSWORD_HASH}"
else
    log_error "openssl 命令未找到，无法生成密码哈希"
    exit 1
fi

# 5. 应用Argon主题优化
if [ "$APPLY_ARGON_TWEAKS" = "true" ]; then
    log_substep "应用Argon主题优化..."
    
    # 调整在Argon主题下，概览页面显示/隐藏按钮的样式
    ARGON_CSS="$OPENWRT_ROOT_DIR/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css"
    if [ -f "$ARGON_CSS" ]; then
        log_info "修改Argon主题CSS样式..."
        safe_backup "$ARGON_CSS"
        
        # 检查是否已经添加过样式，避免重复添加
        if ! grep -q "cbi-section.fade-in .cbi-title" "$ARGON_CSS"; then
            # 添加CSS样式
            cat >> "$ARGON_CSS" << 'EOF'

/* 自定义Argon主题样式 - 由DIY脚本添加 */
.cbi-section.fade-in .cbi-title {
  position: relative;
  min-height: 2.765rem;
  display: flex;
  align-items: center
}
.cbi-section.fade-in .cbi-title>div:last-child {
  position: absolute;
  right: 1rem
}
.cbi-section.fade-in .cbi-title>div:last-child span {
  display: inline-block;
  position: relative;
  font-size: 0
}
.cbi-section.fade-in .cbi-title>div:last-child span::after {
  content: "\e90f";
  font-family: 'argon' !important;
  font-size: 1.1rem;
  display: inline-block;
  transition: transform 0.3s ease;
  -webkit-font-smoothing: antialiased;
  line-height: 1
}
.cbi-section.fade-in .cbi-title>div:last-child span[data-style='inactive']::after {
  transform: rotate(90deg);
}
EOF
            log_debug "Argon主题CSS样式添加完成"
        else
            log_debug "Argon主题CSS样式已存在，跳过添加"
        fi
    else
        log_warn "Argon主题CSS文件未找到，跳过主题样式修改"
    fi
    
    # 修改状态页面的按钮样式
    INDEX_JS="$OPENWRT_ROOT_DIR/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js"
    if [ -f "$INDEX_JS" ]; then
        log_info "修改状态页面按钮样式..."
        safe_backup "$INDEX_JS"
        
        # 删除特定行
        sed -i -e '/btn\.setAttribute(\x27class\x27, include\.hide ? \x27label notice\x27 : \x27label\x27);/d' \
               -e "/\x27class\x27: includes\[i\]\.hide ? \x27label notice\x27 : \x27label\x27,/d" \
               "$INDEX_JS"
        log_debug "状态页面按钮样式修改完成"
    else
        log_warn "状态页面索引JS文件未找到，跳过按钮样式修改"
    fi
else
    log_info "跳过Argon主题优化"
fi

# 显示当前磁盘使用情况
log_info "当前磁盘使用情况:"
df -h

# 记录结束时间并生成摘要
SCRIPT_END_TIME=$(date +%s)
generate_summary "DIY Part 初始配置" "$SCRIPT_START_TIME" "$SCRIPT_END_TIME" "成功"

log_success "DIY Part 初始配置执行完成。"
