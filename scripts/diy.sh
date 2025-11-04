#!/bin/bash

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 在此修改初始管理配置 ---
# 默认 LAN IP 地址
LAN_IP="192.168.31.1"
# 默认 root 用户密码
ROOT_PASSWORD="password"

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

# 1. 修改 LAN IP
log_info "正在设置 LAN IP 为: ${LAN_IP}"
sed -i "s/192.168.1.1/${LAN_IP}/g" "$OPENWRT_ROOT_DIR/package/base-files/files/bin/config_generate"

# 2. 修改 root 密码
log_info "正在设置 root 密码"
# 使用 openssl 生成密码哈希
PASSWORD_HASH=$(openssl passwd -1 "${ROOT_PASSWORD}")
# 替换 shadow 文件中的 root 密码字段
sed -i "s/root:\!/root:${PASSWORD_HASH}/g" "$OPENWRT_ROOT_DIR/package/base-files/files/etc/shadow"

log_success "DIY Part 1 执行完成。"
