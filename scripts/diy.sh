#!/bin/bash

# ==============================================================================
# OpenWrt/ImmortalWrt 自定义配置脚本
#
# 功能:
#   配置设备初始管理IP/密码
#   优化UI样式
#   应用自定义配置
#
# 使用方法:
#   在 OpenWrt/ImmortalWrt 源码根目录下运行此脚本
#
# 作者: Mary
# 日期：20251107
# 版本: 1.0 - 初始版本
# ==============================================================================

# 导入通用函数
source "$(dirname "$0")/common.sh"

# --- 配置变量 ---
# 默认IP地址
DEFAULT_IP="192.168.1.1"
# 默认密码
DEFAULT_PASSWORD="password"
# 默认主题
DEFAULT_THEME="argon"

# --- 主函数 ---

# 显示脚本信息
show_script_info() {
    log_step "OpenWrt/ImmortalWrt 自定义配置脚本"
    log_info "作者: Mary"
    log_info "版本: 1.0 - 初始版本"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查环境
check_environment() {
    log_info "检查执行环境..."
    
    # 检查是否在源码根目录
    if [ ! -f "Makefile" ] || ! grep -q "OpenWrt" Makefile; then
        log_error "不在OpenWrt/ImmortalWrt源码根目录"
        return 1
    fi
    
    log_success "环境检查通过"
    return 0
}

# 配置初始IP和密码
configure_initial_settings() {
    log_info "配置初始IP和密码..."
    
    local ip="${1:-$DEFAULT_IP}"
    local password="${2:-$DEFAULT_PASSWORD}"
    
    # 修改默认IP
    log_info "设置默认IP: $ip"
    sed -i "s/192.168.1.1/$ip/g" package/base-files/files/bin/config_generate
    
    # 生成密码哈希
    local password_hash
    password_hash=$(openssl passwd -1 "$password")
    
    # 修改默认密码
    log_info "设置默认密码"
    sed -i "s/root:::0:99999:7:::/root:$password_hash:18579:0:99999:7:::/g" package/base-files/files/etc/shadow
    
    log_success "初始IP和密码配置完成"
}

# 优化UI样式
optimize_ui_styles() {
    log_info "优化UI样式..."
    
    # 检查主题是否存在
    local theme_dir="feeds/luci/themes/luci-theme-argon"
    if [ ! -d "$theme_dir" ]; then
        log_warning "Argon主题不存在，跳过UI优化"
        return 1
    fi
    
    local css_file="$theme_dir/htdocs/luci-static/argon/css/cascade.css"
    
    if [ ! -f "$css_file" ]; then
        log_warning "Argon主题CSS文件不存在，跳过UI优化"
        return 1
    fi
    
    # 调整在Argon主题下，概览页面显示/隐藏按钮的样式
    log_info "调整概览页面显示/隐藏按钮的样式"
    
    # 备份原文件
    cp "$css_file" "$css_file.bak"
    
    # 修改CSS文件
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
}' "$css_file"
    
    # 修改状态页面JavaScript
    local js_file="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js"
    
    if [ -f "$js_file" ]; then
        log_info "修改状态页面JavaScript"
        
        # 备份原文件
        cp "$js_file" "$js_file.bak"
        
        # 修改JavaScript文件
        sed -i -e '/btn\.setAttribute(\x27class\x27, include\.hide ? \x27label notice\x27 : \x27label\x27);/d' \
               -e "/\x27class\x27: includes\[i\]\.hide ? \x27label notice\x27 : \x27label\x27,/d" \
               "$js_file"
    else
        log_warning "状态页面JavaScript文件不存在，跳过修改"
    fi
    
    log_success "UI样式优化完成"
}

# 应用自定义配置
apply_custom_configurations() {
    log_info "应用自定义配置..."
    
    # 这里可以添加其他自定义配置
    
    log_success "自定义配置应用完成"
}

# 生成摘要报告
generate_final_summary() {
    log_step "生成执行摘要"
    
    show_execution_summary
}

# =============================================================================
# 主执行流程
# =============================================================================

main() {
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 显示脚本信息
    show_script_info
    
    # 检查环境
    if check_environment; then
        # 配置初始IP和密码
        configure_initial_settings "$@"
        
        # 优化UI样式
        optimize_ui_styles
        
        # 应用自定义配置
        apply_custom_configurations
        
        # 生成摘要报告
        generate_final_summary
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
    
    # 返回执行结果
    if [ $ERROR_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"
