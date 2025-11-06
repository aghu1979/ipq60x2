#!/bin/bash
# =============================================================================
# ImmortalWrt DIY配置脚本
# 版本: 1.2
# 作者: Mary
# 描述: 配置设备初始管理IP/密码及系统优化
# =============================================================================

# 加载通用函数库
source "$(dirname "$0")/common.sh"

# 全局变量
REPO_PATH="${REPO_PATH:-$(pwd)}"
INIT_IP="192.168.111.1"
INIT_PASSWORD=""  # 空密码
HOSTNAME="WRT"
AUTHOR="Mary"

log_work "开始执行DIY配置..."

# 显示配置信息
show_initial_config() {
    log_info "初始配置信息:"
    echo "  🌐 LAN IP: $INIT_IP"
    echo "  🔑 Root密码: [空密码]"
    echo "  🖥️  主机名: $HOSTNAME"
    echo "  👤 作者: $AUTHOR"
    echo ""
}

# 配置初始网络和认证
configure_initial_settings() {
    log_info "配置初始管理设置..."
    
    # 创建初始配置文件
    cat > "$REPO_PATH/files/etc/uci-defaults/99-initial-settings" << EOF
#!/bin/sh
# 初始配置脚本
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 作者: $AUTHOR

# 设置LAN IP
uci set network.lan.ipaddr='$INIT_IP'
uci commit network

# 设置root密码为空
passwd -d root

# 配置SSH
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci commit dropbear

# 设置时区
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
    
    chmod +x "$REPO_PATH/files/etc/uci-defaults/99-initial-settings"
    log_success "初始配置设置完成"
}

# 优化编译配置
optimize_build_config() {
    log_info "优化编译配置..."
    
    # 添加编译优化选项
    cat >> "$REPO_PATH/.config" << EOF

# 编译优化
CONFIG_TARGET_OPTIMIZATION="-O2 -pipe -mcpu=cortex-a53"
CONFIG_USE_GLIBC=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_EXT4FS=y

# 禁用不必要的功能
CONFIG_IB=y
CONFIG_KERNEL_GIT_CLONE_URI=""
CONFIG_KERNEL_GIT_REF=""
EOF
    
    log_success "编译配置优化完成"
}

# 添加自定义应用
add_custom_applications() {
    log_info "添加自定义应用..."
    
    # 创建自定义应用目录
    mkdir -p "$REPO_PATH/package/custom"
    
    # 示例：添加自定义启动脚本
    cat > "$REPO_PATH/package/custom/custom-init/Makefile" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=custom-init
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/custom-init
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Custom Initialization Scripts
  DEPENDS:=+luci
endef

define Package/custom-init/install
    $(INSTALL_DIR) $(1)/etc/init.d
    $(INSTALL_BIN) ./files/custom-init.init $(1)/etc/init.d/custom-init
endef

 $(eval $(call BuildPackage,custom-init))
EOF
    
    mkdir -p "$REPO_PATH/package/custom/custom-init/files"
    cat > "$REPO_PATH/package/custom/custom-init/files/custom-init.init" << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    echo "Custom initialization started..."
    # 添加自定义启动逻辑
}

stop() {
    echo "Custom initialization stopped..."
}
EOF
    
    chmod +x "$REPO_PATH/package/custom/custom-init/files/custom-init.init"
    log_success "自定义应用添加完成"
}

# 配置系统优化
configure_system_optimization() {
    log_info "配置系统优化..."
    
    # 创建系统优化脚本
    cat > "$REPO_PATH/files/etc/uci-defaults/98-system-optimization" << 'EOF'
#!/bin/sh
# 系统优化脚本

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
    
    chmod +x "$REPO_PATH/files/etc/uci-defaults/98-system-optimization"
    log_success "系统优化配置完成"
}

# 生成配置说明文件
generate_config_info() {
    log_info "生成配置说明文件..."
    
    cat > "$REPO_PATH/files/etc/uci-defaults/README" << EOF
# ImmortalWrt 初始配置说明
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 作者: $AUTHOR

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

EOF
    
    log_success "配置说明文件生成完成"
}

# 主函数
main() {
    log_work "开始DIY配置流程..."
    
    # 显示配置信息
    show_initial_config
    
    # 检查必要目录
    mkdir -p "$REPO_PATH/files/etc/uci-defaults"
    
    # 执行配置步骤
    configure_initial_settings
    optimize_build_config
    add_custom_applications
    configure_system_optimization
    generate_config_info
    
    log_success "DIY配置完成！"
    echo ""
    log_info "📋 配置摘要:"
    echo "  🌐 管理地址: http://$INIT_IP"
    echo "  🔑 登录账号: root"
    echo "  🔑 登录密码: [空密码]"
    echo "  🖥️  主机名: $HOSTNAME"
    echo ""
}

# 执行主函数
main "$@"
