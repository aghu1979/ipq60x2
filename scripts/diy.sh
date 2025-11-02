#!/bin/bash
# 作者: AI Assistant
# 描述: 为固件镜像应用自定义默认设置。

# --- 配置 ---
DEFAULT_IP="192.168.111.1"
DEFAULT_HOSTNAME="WRT"
# --- 配置结束 ---

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 脚本预期在 immwrt 源码根目录中运行
IMMWRT_ROOT="$(pwd)"

# 创建目录结构以覆盖基础文件
FILES_DIR="$IMMWRT_ROOT/package/base-files/files"
mkdir -p "$FILES_DIR/etc/config"

echo "正在应用自定义网络设置..."

# 设置 LAN IP 地址
cat > "$FILES_DIR/etc/config/network" <<EOF
config interface 'loopback'
    option ifname 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config globals 'globals'
    option ula_prefix 'fd12:3456:789a::/48'

config interface 'lan'
    option type 'bridge'
    option ifname 'eth0'
    option proto 'static'
    option ipaddr '$DEFAULT_IP'
    option netmask '255.255.255.0'
    option ip6assign '60'

config device 'lan_dev'
    option name 'br-lan'
    option type 'bridge'

config interface 'wan'
    option ifname 'eth1'
    option proto 'dhcp'

config interface 'wan6'
    option ifname 'eth1'
    option proto 'dhcpv6'
EOF

echo "正在将默认主机名设置为 '$DEFAULT_HOSTNAME'..."

# 设置系统主机名
# 注意：这可能会被其他配置文件覆盖，但这是一个标准位置。
mkdir -p "$FILES_DIR/etc"
cat > "$FILES_DIR/etc/sysinfo" <<EOF
board.name=ipq60xx
board.model=ImmortalWrt
hostname=$DEFAULT_HOSTNAME
EOF

# 一种更健壮的方式是直接修改系统配置
mkdir -p "$FILES_DIR/etc/uci-defaults"
cat > "$FILES_DIR/etc/uci-defaults/99-set-hostname" <<'EOF'
#!/bin/sh
uci set system.@system[0].hostname='WRT'
uci commit system
EOF
chmod +x "$FILES_DIR/etc/uci-defaults/99-set-hostname"


echo "正在为 root 用户设置空密码..."

# 要设置空密码，我们需要修改最终 rootfs 中的 /etc/shadow 文件。
# 密码字段中的 '!' 会锁定账户。空字段允许无密码登录。
# 我们创建一个 uci-defaults 脚本在首次启动时处理此操作。
cat > "$FILES_DIR/etc/uci-defaults/99-set-empty-password" <<'EOF'
#!/bin/sh
# 此脚本在首次启动时运行，以设置空的 root 密码。
# 它用密码字段为空的行替换 /etc/shadow 中的 root 行。
sed -i 's|^root:[^:]*:|root::|' /etc/shadow
EOF
chmod +x "$FILES_DIR/etc/uci-defaults/99-set-empty-password"

echo "DIY 脚本执行完毕。IP: $DEFAULT_IP, 主机名: $DEFAULT_HOSTNAME, 密码: 空。"
