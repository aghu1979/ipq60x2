#!/bin/bash
# 固件DIY脚本 - 精简优化版本
# 功能：设置固件初始配置

set -euo pipefail

# 日志函数
log() {
  echo -e "\033[32m[INFO]\033[0m $*"
}

error() {
  echo -e "\033[31m[ERROR]\033[0m $*"
  exit 1
}

warning() {
  echo -e "\033[33m[WARN]\033[0m $*"
}

# 设置默认IP为192.168.111.1
log "设置默认IP为192.168.111.1..."
sed -i 's/192.168.1.1/192.168.111.1/g' || error "修改默认IP失败"

# 设置密码为空
log "设置密码为空..."
sed -i 's/root::0:0:0:99999:7:::/g' package/base-files/files/etc/shadow || error "设置密码为空失败"

# 设置机器名为WRT
log "设置机器名为WRT..."
sed -i 's/OpenWrt/WRT/g' || error "设置机器名失败"

# 调整Argon主题显示
if [ -d "feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css" ]; then
    log_info "优化Argon主题显示..."
    sed -i '/^\.td\.cbi-section-actions {$/,/^}$/ {
      /^}$/a\
        /^}$/a\
        echo ' \
.cbi-section.fade-in .cbi-section-actions {$/,/^}$/ {
          /^}$/a\
          echo ' \
.cbi-section.fade-in .cbi-section-actions {\
            position: relative;\
            min-height: 2.765rem\
            display: flex;\
            align-items: center;\
            right: 1rem\
            position: absolute;\
            right: 1rem\
          '}' \
        } \
    ' feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css || error "优化Argon主题失败"
    log_info "Argon主题优化完成"
else
    warning "未找到Argon主题，跳过优化"
fi

log_info "自定义配置应用完成"
