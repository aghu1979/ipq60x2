#!/bin/bash

# 设置日志函数
log() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
  exit 1
}

warning() {
  echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# 设置默认IP为192.168.111.1
log "设置默认IP为192.168.111.1..."
sed -i 's/192.168.1.1/192.168.111.1/g' package/base-files/files/bin/config_generate || error "修改默认IP失败"

# 设置密码为空
log "设置密码为空..."
sed -i 's/root::0:0:99999:7:::/root:::0:0:99999:7:::/g' package/base-files/files/etc/shadow || error "设置密码为空失败"

# 设置机器名为WRT
log "设置机器名为WRT..."
sed -i 's/OpenWrt/WRT/g' package/base-files/files/bin/config_generate || error "设置机器名失败"

# 调整Argon主题显示
if [ -d "feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css" ]; then
  log "优化Argon主题显示..."
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
}' feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css || error "优化Argon主题失败"
  log "Argon主题优化完成"
else
  warning "未找到Argon主题，跳过优化"
fi

log "自定义配置应用完成"
