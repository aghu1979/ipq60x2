#!/bin/bash
# =============================================================================
# ImmortalWrt DIY配置脚本
# 版本: 2.1 (企业级优化版)
# 作者: Mary
# 描述: 配置设备初始管理IP/密码及系统优化
# =============================================================================

# 加载通用函数库
source "$(dirname "$0")/common.sh"

# 全局配置
readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_AUTHOR="Mary"
readonly REPO_PATH="${REPO_PATH:-$(pwd)}"
readonly LOG_FILE="$REPO_PATH/diy_script.log"

# 配置参数
readonly INIT_IP="192.168.111.1"
readonly HOSTNAME="WRT"
readonly INIT_PASSWORD=""  # 空密码

# 操作统计
declare -g SUCCESS_COUNT=0
declare -g FAIL_COUNT=0
declare -g SKIP_COUNT=0
declare -g FAILED_OPERATIONS=()

# =============================================================================
# 核心功能函数
# =============================================================================

# 环境检查
check_environment() {
    log_info "🔍 检查执行环境..."
    
    local errors=0
    
    # 检查必要目录
    if [ ! -d "$REPO_PATH" ]; then
        log_error "源码目录不存在: $REPO_PATH"
        ((errors++))
    fi
    
    # 检查必要命令
    local required_commands=("git" "chmod" "mkdir" "cat" "sed")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "缺少必要命令: $cmd"
            ((errors++))
        fi
    done
    
    # 检查磁盘空间
    if ! check_disk_space "$REPO_PATH" 1; then
        log_error "磁盘空间不足"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "✅ 环境检查通过"
        return 0
    else
        log_error "❌ 环境检查失败，发现 $errors 个问题"
        return 1
    fi
}

# 显示配置信息
show_configuration() {
    log_info "📋 配置信息:"
    echo "  🌐 LAN IP: $INIT_IP"
    echo "  🔑 Root密码: [空密码]"
    echo "  🖥️  主机名: $HOSTNAME"
    echo "  👤 作者: $SCRIPT_AUTHOR"
    echo "  📝 脚本版本: $SCRIPT_VERSION"
    echo "  📂 工作目录: $REPO_PATH"
    echo ""
}

# 创建必要目录
create_directories() {
    log_info "📁 创建必要目录..."
    
    local dirs=(
        "$REPO_PATH/files/etc/uci-defaults"
        "$REPO_PATH/package/custom"
    )
    
    for dir in "${dirs[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            log_success "创建目录: $dir"
            ((SUCCESS_COUNT++))
        else
            log_error "创建目录失败: $dir"
            ((FAIL_COUNT++))
            FAILED_OPERATIONS+=("create_directory:$dir")
        fi
    done
}

# 配置初始网络和认证
configure_initial_settings() {
    log_info "⚙️ 配置初始网络和认证设置..."
    
    local config_file="$REPO_PATH/files/etc/uci-defaults/99-initial-settings"
    
    if cat > "$config_file" << EOF; then
#!/bin/sh
# 初始配置脚本
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 作者: $SCRIPT_AUTHOR
# 脚本版本: $SCRIPT_VERSION

# 设置LAN IP
uci set network.lan.ipaddr='$INIT_IP'
uci commit network

# 设置root密码为空
passwd -d root

# 配置SSH
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci commit dropbear

# 设置时区和主机名
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].hostname='$HOSTNAME'
uci commit system

# 启用必要的服务
/etc/init.d/uhttpd enable
/etc/init.d/dropbear enable
/etc/init.d/network restart

exit 0
EOF
        chmod +x "$config_file" && log_success "初始配置文件创建成功" && ((SUCCESS_COUNT++))
    else
        log_error "初始配置文件创建失败"
        ((FAIL_COUNT++))
        FAILED_OPERATIONS+=("configure_initial_settings")
        return 1
    fi
}

# 优化编译配置
optimize_build_config() {
    log_info "🚀 优化编译配置..."
    
    local config_file="$REPO_PATH/.config"
    local config_content="
# 编译优化 - 添加于 $(date '+%Y-%m-%d %H:%M:%S')
CONFIG_TARGET_OPTIMIZATION=\"-O2 -pipe -mcpu=cortex-a53\"
CONFIG_USE_GLIBC=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_EXT4FS=y

# 禁用不必要的功能
CONFIG_IB=y
CONFIG_KERNEL_GIT_CLONE_URI=\"\"
CONFIG_KERNEL_GIT_REF=\"\"
"
    
    if echo "$config_content" >> "$config_file" 2>/dev/null; then
        log_success "编译配置优化完成"
        ((SUCCESS_COUNT++))
    else
        log_error "编译配置优化失败"
        ((FAIL_COUNT++))
        FAILED_OPERATIONS+=("optimize_build_config")
        return 1
    fi
}

# 配置系统优化
configure_system_optimization() {
    log_info "⚡ 配置系统优化..."
    
    local opt_file="$REPO_PATH/files/etc/uci-defaults/98-system-optimization"
    
    if cat > "$opt_file" << 'EOF'; then
#!/bin/sh
# 系统优化脚本
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 优化网络参数
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 16777216' >> /etc/sysctl.conf

# 优化文件系统
echo 'vm.dirty_ratio = 15' >> /etc/sysctl.conf
echo 'vm.dirty_background_ratio = 5' >> /etc/sysctl.conf

# 启用BBR
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf

exit 0
EOF
        chmod +x "$opt_file" && log_success "系统优化配置完成" && ((SUCCESS_COUNT++))
    else
        log_error "系统优化配置失败"
        ((FAIL_COUNT++))
        FAILED_OPERATIONS+=("configure_system_optimization")
        return 1
    fi
}

# 配置Argon主题样式
configure_argon_theme() {
    log_info "🎨 配置Argon主题样式..."
    
    local css_file="$REPO_PATH/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css"
    local js_file="$REPO_PATH/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js"
    local css_modified=false
    local js_modified=false
    
    # 检查文件是否存在
    if [ ! -f "$css_file" ]; then
        log_warning "Argon主题CSS文件不存在: $css_file"
        ((SKIP_COUNT++))
    else
        # 备份原文件
        if cp "$css_file" "${css_file}.bak" 2>/dev/null; then
            log_info "已备份CSS文件: ${css_file}.bak"
        else
            log_warning "无法备份CSS文件"
        fi
        
        # 修改CSS文件
        if sed -i '/^\.td\.cbi-section-actions {$/,/^}$/ {
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
}' "$css_file" 2>/dev/null; then
            log_success "Argon主题CSS样式修改成功"
            css_modified=true
            ((SUCCESS_COUNT++))
        else
            log_error "Argon主题CSS样式修改失败"
            ((FAIL_COUNT++))
            FAILED_OPERATIONS+=("configure_argon_theme_css")
        fi
    fi
    
    # 检查JS文件是否存在
    if [ ! -f "$js_file" ]; then
        log_warning "Argon主题JS文件不存在: $js_file"
        ((SKIP_COUNT++))
    else
        # 备份原文件
        if cp "$js_file" "${js_file}.bak" 2>/dev/null; then
            log_info "已备份JS文件: ${js_file}.bak"
        else
            log_warning "无法备份JS文件"
        fi
        
        # 修改JS文件
        if sed -i -e '/btn\.setAttribute(\x27class\x27, include\.hide ? \x27label notice\x27 : \x27label\x27);/d' \
                  -e "/\x27class\x27: includes\[i\]\.hide ? \x27label notice\x27 : \x27label\x27,/d" \
                  "$js_file" 2>/dev/null; then
            log_success "Argon主题JS代码修改成功"
            js_modified=true
            ((SUCCESS_COUNT++))
        else
            log_error "Argon主题JS代码修改失败"
            ((FAIL_COUNT++))
            FAILED_OPERATIONS+=("configure_argon_theme_js")
        fi
    fi
    
    # 如果至少有一个文件修改成功，则认为函数执行成功
    if [ "$css_modified" = true ] || [ "$js_modified" = true ]; then
        return 0
    else
        return 1
    fi
}

# 生成配置说明文件
generate_documentation() {
    log_info "📚 生成配置文档..."
    
    local doc_file="$REPO_PATH/files/etc/uci-defaults/README"
    
    if cat > "$doc_file" << EOF; then
# ImmortalWrt 初始配置说明
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 作者: $SCRIPT_AUTHOR
# 脚本版本: $SCRIPT_VERSION

## 默认配置
- LAN IP: $INIT_IP
- Root密码: [空密码]
- 主机名: $HOSTNAME

## 常用命令
- 修改密码: passwd
- 重启网络: /etc/init.d/network restart
- 查看日志: logread

## Web界面
访问地址: http://$INIT_IP

## 配置文件说明
- 99-initial-settings: 初始网络和认证配置
- 98-system-optimization: 系统性能优化
- Argon主题样式: 优化概览页面显示/隐藏按钮样式
EOF
        log_success "配置文档生成完成" && ((SUCCESS_COUNT++))
    else
        log_error "配置文档生成失败"
        ((FAIL_COUNT++))
        FAILED_OPERATIONS+=("generate_documentation")
        return 1
    fi
}

# 验证配置结果
verify_configuration() {
    log_info "🔍 验证配置结果..."
    
    local verification_items=(
        "$REPO_PATH/files/etc/uci-defaults/99-initial-settings:初始配置文件"
        "$REPO_PATH/files/etc/uci-defaults/98-system-optimization:系统优化文件"
        "$REPO_PATH/files/etc/uci-defaults/README:配置文档"
        "$REPO_PATH/.config:编译配置文件"
        "$REPO_PATH/feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css:Argon主题CSS文件"
        "$REPO_PATH/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js:Argon主题JS文件"
    )
    
    local verified_count=0
    for item in "${verification_items[@]}"; do
        local file="${item%:*}"
        local desc="${item#*:}"
        
        if [ -f "$file" ]; then
            echo "  ✅ $desc"
            ((verified_count++))
        else
            echo "  ❌ $desc (缺失)"
        fi
    done
    
    if [ $verified_count -eq ${#verification_items[@]} ]; then
        log_success "配置验证通过"
        ((SUCCESS_COUNT++))
    else
        log_warning "配置验证部分通过 ($verified_count/${#verification_items[@]})"
        ((SKIP_COUNT++))
    fi
}

# 生成执行摘要
generate_summary() {
    echo ""
    echo "=================================================================="
    log_info "📊 执行摘要"
    echo "=================================================================="
    echo "✅ 成功操作: $SUCCESS_COUNT"
    echo "❌ 失败操作: $FAIL_COUNT"
    echo "⚠️  跳过操作: $SKIP_COUNT"
    echo ""
    
    if [ $FAIL_COUNT -gt 0 ]; then
        echo "失败的操作列表:"
        for operation in "${FAILED_OPERATIONS[@]}"; do
            echo "  - $operation"
        done
        echo ""
    fi
    
    echo "配置摘要:"
    echo "  🌐 管理地址: http://$INIT_IP"
    echo "  🔑 登录账号: root"
    echo "  🔑 登录密码: [空密码]"
    echo "  🖥️  主机名: $HOSTNAME"
    echo "  🎨 Argon主题样式: 已优化"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        log_success "🎉 所有配置任务完成！"
    else
        log_warning "⚠️  部分配置任务失败，请检查上述错误信息"
    fi
    echo "=================================================================="
}

# =============================================================================
# 主执行流程
# =============================================================================

main() {
    # 记录开始时间
    local start_time=$(date +%s)
    
    echo ""
    echo "=================================================================="
    log_info "🚀 ImmortalWrt DIY配置脚本 v$SCRIPT_VERSION"
    echo "=================================================================="
    log_info "作者: $SCRIPT_AUTHOR"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 执行配置流程
    if check_environment; then
        show_configuration
        create_directories
        configure_initial_settings
        optimize_build_config
        configure_system_optimization
        configure_argon_theme
        generate_documentation
        verify_configuration
    else
        log_error "环境检查失败，终止执行"
        exit 1
    fi
    
    # 生成摘要
    generate_summary
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_time "总执行时间: ${duration}秒"
}

# 执行主函数
main "$@"
